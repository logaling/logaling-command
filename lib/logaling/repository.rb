# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Miho SUZUKI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "fileutils"
require "logaling/glossary_db"
require "logaling/project"

module Logaling
  class Repository
    def initialize(path)
      @path = path
    end

    def register(dot_logaling_path, register_name)
      FileUtils.mkdir_p(logaling_projects_path)
      symlink_path = File.join(logaling_projects_path, register_name)
      unless File.exist?(symlink_path)
        FileUtils.ln_s(dot_logaling_path, symlink_path)
      else
        raise Logaling::GlossaryAlreadyRegistered, register_name
      end
    rescue Logaling::GlossaryAlreadyRegistered => e
      raise e
    rescue
      raise Logaling::CommandFailed, "Failed register #{register_name} to #{logaling_projects_path}."
    end

    def unregister(project)
      raise Logaling::ProjectNotFound unless project
      FileUtils.rm_rf(project.path, :secure => true)
    end

    def create_personal_project(project_name, source_language, target_language)
      if glossary_exists?(project_name, source_language, target_language)
        raise Logaling::GlossaryAlreadyRegistered, "The glossary '#{project_name}' already exists."
      end
      PersonalProject.create(personal_glossary_root_path, project_name, source_language, target_language)
    end

    def import(glossary_source)
      FileUtils.mkdir_p(cache_path)
      Dir.chdir(cache_path) do
        glossary_source.import
      end
    rescue
      raise Logaling::CommandFailed, "Failed import #{glossary_source.class.name} to #{cache_path}."
    end

    def import_tmx(glossary_source, glossary, url)
      FileUtils.mkdir_p(cache_path)
      Dir.chdir(cache_path) do
        glossary_source.import(glossary, url)
      end
    rescue Logaling::GlossaryNotFound => e
      raise e
    rescue
      raise Logaling::CommandFailed, "Failed import_tmx #{glossary_source.class.name} to #{cache_path}."
    end

    def lookup(source_term, glossary, dictionary=false)
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        if dictionary
          terms = db.lookup_dictionary(source_term)
        else
          terms = db.lookup(source_term, glossary)
        end
      end
      terms
    end

    def projects
      projects = registered_project_paths.map do |project_path|
        Logaling::Project.new(project_path, self)
      end
      projects += personal_glossary_paths.map do |personal_glossary_path|
        Logaling::PersonalProject.new(personal_glossary_path, self)
      end
      projects += imported_glossary_paths.map do |imported_project_path|
        Logaling::ImportedProject.new(imported_project_path, self)
      end
      projects.sort_by(&:path)
    end

    def index
      all_glossary_sources = projects.map{|project| project.glossary_sources}.flatten

      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        db.recreate_table
        all_glossary_sources.each do |glossary_source|
          glossary = glossary_source.glossary
          unless db.glossary_source_exist?(glossary_source)
            puts "now index #{glossary.name}..."
            db.index_glossary(glossary, glossary_source)
          end
        end
        (db.get_all_glossary_sources - all_glossary_sources).each do |glossary_source|
          glossary = glossary_source.glossary
          puts "now deindex #{glossary.name}..."
          db.deindex_glossary(glossary, glossary_source)
        end
      end
    end

    def glossary_counts
      [registered_project_paths, imported_glossary_paths].map(&:size).inject(&:+)
    end

    def config_path
      path = File.join(@path, "config")
      File.exist?(path) ? path : nil
    end

    def find_project(project_name)
      project = projects.detect{|project| project.name == project_name}
    end

    def find_glossary(project_name, source_language, target_language)
      project_candidates = projects.reject { |project| project.name != project_name }
      project = project_candidates.detect do |project|
        project.has_glossary?(source_language, target_language)
      end
      project ? project.glossary(source_language, target_language) : nil
    end

    def logaling_db_home
      File.join(@path, "db")
    end

    private
    def logaling_projects_path
      File.join(@path, "projects")
    end

    def personal_glossary_root_path
      File.join(@path, "personal")
    end

    def cache_path
      File.join(@path, "cache")
    end

    def registered_project_paths
      Dir[File.join(logaling_projects_path, "*")]
    end

    def personal_glossary_paths
      Dir[File.join(personal_glossary_root_path, "*")]
    end

    def imported_glossary_paths
      Dir[File.join(cache_path, "*")]
    end

    def glossary_exists?(project_name, source_language, target_language)
      glossary = find_glossary(project_name, source_language, target_language) ? true : false
    end
  end
end
