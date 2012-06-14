# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Miho SUZUKI
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
module Logaling
  class Glossary
    SUPPORTED_FILE_TYPE = %w(yml tsv csv)

    attr_reader :name, :source_language, :target_language

    def initialize(name, source_language, target_language, project=nil)
      @name = name
      @source_language = source_language
      @target_language = target_language
      @project = project
    end

    def terms
      raise Logaling::GlossaryDBNotFound unless File.exist?(@project.glossary_db_path)
      index
      terms = []
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        terms = db.translation_list(self)
      end
      terms
    end

    def bilingual_pair_exists?(source_term, target_term, note=nil)
      raise Logaling::GlossaryDBNotFound unless File.exist?(@project.glossary_db_path)
      index
      terms = []
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        terms = db.get_bilingual_pair(source_term, target_term, @name, note)
      end
      !terms.empty?
    end

    def add(source_term, target_term, note)
      glossary_source.add(source_term, target_term, note)
    end

    def update(source_term, target_term, new_target_term, note)
      glossary_source.update(source_term, target_term, new_target_term, note)
    end

    def delete(source_term, target_term)
      glossary_source.delete(source_term, target_term)
    end

    def delete_all(source_term, force=false)
      glossary_source.delete_all(source_term, force)
    end

    def glossary_source
      if @glossary_source
        @glossary_source
      else
        file_name = [@name, @source_language, @target_language, 'yml'].join('.')
        source_dir = @project.glossary_source_path
        FileUtils.mkdir_p(source_dir)
        source_path = File.join(source_dir, file_name)
        Logaling::GlossarySource.new(source_path, self)
      end
    end

    private
    def index
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        db.recreate_table
        glossary_sources.each do |glossary_source|
          indexed_at = File.mtime(glossary_source)
          unless db.glossary_source_exist?(glossary_source, indexed_at)
            puts "now index #{@name}..."
            db.index_glossary(@name, glossary_source, @source_language, @target_language)
          end
        end
        glossary_string = [@name, @source_language, @target_language].join('.')
        indexed_glossary_sources = db.glossary_sources_related_on_glossary(glossary_string)
        (indexed_glossary_sources - glossary_sources).each do |removed_glossary_source|
          puts "now deindex #{@name}..."
          db.deindex_glossary(@name, removed_glossary_source)
        end
      end
    end

    def glossary_sources
      glob_condition = SUPPORTED_FILE_TYPE.map do |type|
        file_name = [@name, @source_language, @target_language, type].join('.')
        File.join(@project.glossary_source_path, file_name)
      end
      Dir.glob(glob_condition)
    end
  end
end
