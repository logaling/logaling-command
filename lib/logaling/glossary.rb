# -*- coding: utf-8 -*-
#
#    Copyright (C) 2011  Miho SUZUKI
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'psych'
require "yaml"
require "fileutils"

module Logaling
  class Glossary
    class << self
      def load(file)
        load_glossary(file)
      end

      def load_glossary(file)
        case File.extname(file)
        when ".csv"
          load_glossary_csv(file)
        when ".tsv"
          load_glossary_tsv(file)
        when ".yml"
          load_glossary_yml(file)
        end
      end

      def load_glossary_yml(path)
        YAML::load_file(path) || []
      end

      def load_glossary_tsv(path)
        load_glossary_csv(path, "\t")
      end

      def load_glossary_csv(path, sep=",")
        glossary = []
        CSV.open(path, "r",  {:col_sep => sep}) do |csv|
          csv.each do |row|
            glossary << {"source_term" => row[0], "target_term" => row[1], "note" => ""} if row.size >= 2
          end
        end
        glossary
      end

      def build_path(glossary, source_language, target_language)
        fname = [glossary, source_language, target_language].join(".")
        File.join(LOGALING_HOME, "projects", glossary, "glossary", "#{fname}.yml")
      end
    end

    def initialize(glossary, source_language, target_language)
      @path = Glossary.build_path(glossary, source_language, target_language)
      @glossary = glossary
      @source_language = source_language
      @target_language = target_language
    end

    def add(source_term, target_term, note)
      FileUtils.touch(@path) unless File.exist?(@path)

      glossary = Glossary.load_glossary(@path)
      if bilingual_pair_exists?(glossary, source_term, target_term)
        raise TermError, "term '#{source_term}: #{target_term}' already exists in '#{@glossary}'"
      end

      glossary << build_term(source_term, target_term, note)
      dump_glossary(glossary)
    end

    def update(source_term, target_term, new_target_term, note)
      raise GlossaryNotFound unless File.exist?(@path)

      glossary = Glossary.load_glossary(@path)
      if bilingual_pair_exists?(glossary, source_term, new_target_term)
        raise TermError, "term '#{source_term}: #{target_term}' already exists in '#{@glossary}'"
      end

      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary[target_index] = rebuild_term(glossary[target_index], source_term, new_target_term, note)
        dump_glossary(glossary)
      else
        raise TermError, "Can't found term '#{source_term}: #{target_term}' in '#{@glossary}'"
      end
    end

    def delete(source_term, target_term)
      raise GlossaryNotFound unless File.exist?(@path)

      glossary = Glossary.load_glossary(@path)
      target_index = find_term_index(glossary, source_term, target_term)
      unless target_index
        raise TermError, "Can't found term '#{source_term} #{target_term}' in '#{@glossary}'" unless target_index
      end

      glossary.delete_at(target_index)
      dump_glossary(glossary)
    end

    def delete_all(source_term, force=false)
      raise GlossaryNotFound unless File.exist?(@path)

      glossary = Glossary.load_glossary(@path)
      delete_candidates = target_terms(glossary, source_term)
      if delete_candidates.empty?
        raise TermError, "Can't found term '#{source_term} in '#{@glossary}'"
      end

      if delete_candidates.size == 1 || force
        glossary.delete_if{|term| term['source_term'] == source_term }
        dump_glossary(glossary)
      else
        raise TermError, "There are duplicate terms in glossary.\n" +
          "If you really want to delete, please put `loga delete [SOURCE_TERM] --force`\n" +
          " or `loga delete [SOURCE_TERM] [TARGET_TERM]`"
      end
    end

    private
    def build_term(source_term, target_term, note)
      note ||= ''
      {'source_term' => source_term, 'target_term' => target_term, 'note' => note}
    end

    def rebuild_term(current, source_term, target_term, note)
      note = current['note'] if note.nil? || note == ""
      target_term = current['target_term'] if target_term == ""
      build_term(source_term, target_term, note)
    end

    def find_term_index(glossary, source_term, target_term='')
      glossary.find_index do |term|
        if target_term.empty?
          term['source_term'] == source_term
        else
          term['source_term'] == source_term && term['target_term'] == target_term
        end
      end
    end

    def bilingual_pair_exists?(glossary, source_term, target_term)
      target_terms(glossary, source_term).any?{|data| data['target_term'] == target_term }
    end

    def target_terms(glossary, source_term)
      glossary.select {|term| term['source_term'] == source_term }
    end

    def dump_glossary(glossary)
      File.open(@path, "w") do |f|
        f.puts(glossary.to_yaml)
      end
    end
  end
end
