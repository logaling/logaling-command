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

module Logaling
  class Repository
    def initialize(path)
      @path = path
    end

    def register(dot_logaling_path, register_name)
      FileUtils.mkdir_p(logaling_projects_path) unless File.exist?(logaling_projects_path)
      symlink_path = File.join(logaling_projects_path, register_name)
      unless File.exist?(symlink_path)
        FileUtils.ln_s(dot_logaling_path, symlink_path)
      else
        raise GlossaryAlreadyRegistered, register_name
      end
    end

    def unregister(register_name)
      symlink_path = File.join(logaling_projects_path, register_name)
      if File.exist?(symlink_path)
        FileUtils.remove_entry_secure(symlink_path, true)
      else
        raise GlossaryNotFound, register_name
      end
    end

    def import(glossary)
      FileUtils.mkdir_p(cache_path) unless File.exist?(cache_path)
      Dir.chdir(cache_path) do
        glossary.import
      end
    end

    def lookup(source_term, source_language, target_language, glossary)
      raise GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.lookup(source_term)
        terms.delete_if{|term| term[:source_language] != source_language } if source_language
        terms.delete_if{|term| term[:target_language] != target_language } if target_language
        if glossary && !terms.empty?
          # order by glossary
          specified = terms.select{|term| term[:name] == glossary}
          other = terms.select{|term| term[:name] != glossary}
          terms = specified.concat(other)
        end
      end
      terms
    end

    def index
      projects = Dir[File.join(@path, "projects", "*")]

      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        db.recreate_table
        projects.each do |project|
          get_glossaries_from_project(project).each do |glossary, name, source_language, target_language|
            db.index_glossary(glossary, name, source_language, target_language)
          end
        end
        get_glossaries(cache_path).each do |glossary, name, source_language, target_language|
          db.index_glossary(glossary, name, source_language, target_language)
        end
      end
    end

    def glossary_counts
      [registered_projects, imported_glossaries].map(&:size).inject(&:+)
    end

    def config_path
      path = File.join(@path, "config")
      File.exist?(path) ? path : nil
    end

    private
    def get_glossaries(path)
      glob_list = %w(yml tsv csv).map{|type| File.join(path, "*.#{type}") }
      Dir.glob(glob_list).map do |file|
        name, source_language, target_language = File::basename(file, ".*").split(".")
        [Glossary.load(file), name, source_language, target_language]
      end
    end

    def get_glossaries_from_project(path)
      get_glossaries(File.join(path, "glossary"))
    end

    def logaling_db_home
      File.join(@path, "db")
    end

    def logaling_projects_path
      File.join(@path, "projects")
    end

    def cache_path
      File.join(@path, "cache")
    end

    def registered_projects
      Dir[File.join(logaling_projects_path, "*")]
    end

    def imported_glossaries
      Dir[File.join(cache_path, "*")]
    end
  end
end
