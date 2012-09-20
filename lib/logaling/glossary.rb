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
    SUPPORTED_ANNOTATION = %w(wip)

    attr_reader :name, :source_language, :target_language

    def initialize(name, source_language, target_language, project=nil)
      @name = name
      @source_language = source_language
      @target_language = target_language
      @project = project
    end

    def terms(annotation_word=nil)
      raise Logaling::GlossaryDBNotFound unless File.exist?(@project.glossary_db_path)
      index
      terms = []
      filter_option = annotation_word ? '@' + annotation_word : annotation_word
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        terms = db.translation_list(self, filter_option)
      end
      terms
    end

    def find_bilingual_pairs(source_term, target_term, note=nil)
      raise Logaling::GlossaryDBNotFound unless File.exist?(@project.glossary_db_path)
      index
      terms = []
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        terms = db.get_bilingual_pair(source_term, target_term, @name, note)
      end
      terms.delete_if {|t| t[:target_language] != @target_language }
    end

    def bilingual_pair_exists?(source_term, target_term, note=nil)
      !find_bilingual_pairs(source_term, target_term, note).empty?
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
        @glossary_source = Logaling::GlossarySource.create(source_path, self)
      end
    end

    def merge!(glossary)
      glossary.terms.each do |term|
        add(term[:source_term], term[:target_term], term[:note])
      end
    end

    def initialize_glossary_source
      glossary_source.initialize_source
    end

    def to_s
      [@name, @source_language, @target_language].join('.')
    end

    private
    def index
      Logaling::GlossaryDB.open(@project.glossary_db_path, "utf8") do |db|
        db.recreate_table
        glossary_sources.each do |glossary_source|
          unless db.glossary_source_exist?(glossary_source)
            puts "now index #{@name}..."
            db.index_glossary_source(glossary_source)
          end
        end
        indexed_glossary_sources = db.glossary_sources_related_on_glossary(self)
        (indexed_glossary_sources - glossary_sources).each do |removed_glossary_source|
          puts "now deindex #{@name}..."
          db.deindex_glossary_source(removed_glossary_source)
        end
      end
    end

    def glossary_sources
      glob_condition = SUPPORTED_FILE_TYPE.map do |type|
        file_name = [self.to_s, type].join('.')
        File.join(@project.glossary_source_path, file_name)
      end
      Dir.glob(glob_condition).map {|source_path| GlossarySource.create(source_path, self)}
    end
  end
end
