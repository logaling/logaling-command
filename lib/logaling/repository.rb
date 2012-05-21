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
        raise Logaling::GlossaryAlreadyRegistered, register_name
      end
    rescue
      raise Logaling::CommandFailed, "Failed register #{register_name} to #{logaling_projects_path}."
    end

    def unregister(register_name)
      symlink_path = File.join(logaling_projects_path, register_name)
      if File.exist?(symlink_path)
        FileUtils.remove_entry_secure(symlink_path, true)
      else
        raise Logaling::GlossaryNotFound, register_name
      end
    end

    def import(glossary)
      FileUtils.mkdir_p(cache_path) unless File.exist?(cache_path)
      Dir.chdir(cache_path) do
        glossary.import
      end
    rescue
      raise Logaling::CommandFailed, "Failed import #{glossary.class.name} to #{cache_path}."
    end

    def import_tmx(glossary, glossary_info)
      FileUtils.mkdir_p(cache_path) unless File.exist?(cache_path)
      Dir.chdir(cache_path) do
        glossary.import(glossary_info)
      end
    rescue Logaling::GlossaryNotFound => e
      raise e
    rescue
      raise Logaling::CommandFailed, "Failed import_tmx #{glossary.class.name} to #{cache_path}."
    end

    def lookup(source_term, glossary_source, dictionary=false)
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        if dictionary
          terms = db.lookup_dictionary(source_term)
        else
          terms = db.lookup(source_term, glossary_source)
        end
      end
      terms
    end

    def show_glossary(glossary_source)
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.translation_list(glossary_source)
      end
      terms
    end

    def list
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      glossaries = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        glossaries = db.get_all_glossary
      end
      glossaries
    end

    def index
      project_glossaries = Dir[File.join(@path, "projects", "*")].map do |project|
        Dir.glob(get_all_glossary_sources(File.join(project, "glossary")))
      end
      imported_glossaries = Dir.glob(get_all_glossary_sources(cache_path))
      all_glossaries = project_glossaries.flatten + imported_glossaries

      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        db.recreate_table
        all_glossaries.each do |glossary_source|
          indexed_at = File.mtime(glossary_source)
          unless db.glossary_source_exist?(glossary_source, indexed_at)
            glossary_name, source_language, target_language = get_glossary(glossary_source)
            puts "now index #{glossary_name}..."
            db.index_glossary(Glossary.load(glossary_source), glossary_name, glossary_source, source_language, target_language, indexed_at)
          end
        end
        (db.get_all_glossary_source - all_glossaries).each do |glossary_source|
          glossary_name, source_language, target_language = get_glossary(glossary_source)
          puts "now deindex #{glossary_name}..."
          db.deindex_glossary(glossary_name, glossary_source)
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

    def bilingual_pair_exists?(source_term, target_term, glossary)
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.get_bilingual_pair(source_term, target_term, glossary)
      end

      if terms.size > 0
        true
      else
        false
      end
    end

    def bilingual_pair_exists_and_has_same_note?(source_term, target_term, note, glossary)
      raise Logaling::GlossaryDBNotFound unless File.exist?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.get_bilingual_pair_with_note(source_term, target_term, note, glossary)
      end

      if terms.size > 0
        true
      else
        false
      end
    end

    private
    def get_glossary(path)
      glossary_name, source_language, target_language = File::basename(path, ".*").split(".")
      [glossary_name, source_language, target_language]
    end

    def get_all_glossary_sources(path)
      %w(yml tsv csv).map{|type| File.join(path, "*.#{type}") }
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
