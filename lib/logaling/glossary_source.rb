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

begin
  require 'psych'
rescue LoadError => e
  raise LoadError unless e.message =~ /psych/
  puts "please install psych first."
end
require "yaml"
require "csv"
require "fileutils"

module Logaling
  class GlossarySource
    class << self
      def load(file)
        load_glossary_source(file)
      end

      def load_glossary_source(file)
        case File.extname(file)
        when ".csv"
          load_glossary_source_csv(file)
        when ".tsv"
          load_glossary_source_tsv(file)
        when ".yml"
          load_glossary_source_yml(file)
        end
      end

      def load_glossary_source_yml(path)
        YAML::load_file(path) || []
      end

      def load_glossary_source_tsv(path)
        load_glossary_source_csv(path, "\t")
      end

      def load_glossary_source_csv(path, sep=",")
        glossary_source = []
        CSV.open(path, "r:utf-8",  {:col_sep => sep}) do |csv|
          csv.each do |row|
            glossary_source << {"source_term" => row[0], "target_term" => row[1], "note" => ""} if row.size >= 2
          end
        end
        glossary_source
      end
    end
    attr_reader :glossary, :source_language, :target_language
    attr_writer :source_path

    def initialize(glossary_name, source_language, target_language, logaling_home = nil)
      @logaling_home = logaling_home
      @glossary = glossary_name
      @source_language = source_language
      @target_language = target_language
    end

    def add(source_term, target_term, note)
      FileUtils.touch(source_path) unless File.exist?(source_path)

      glossary_source = GlossarySource.load_glossary_source(source_path)
      glossary_source << build_term(source_term, target_term, note)
      dump_glossary_source(glossary_source)
    rescue
      raise GlossaryNotFound
    end

    def update(source_term, target_term, new_target_term, note)
      raise GlossaryNotFound unless File.exist?(source_path)

      glossary_source = GlossarySource.load_glossary_source(source_path)

      target_index = find_term_index(glossary_source, source_term, target_term)
      if target_index
        glossary_source[target_index] = rebuild_term(glossary_source[target_index], source_term, new_target_term, note)
        dump_glossary_source(glossary_source)
      else
        raise TermError, "Can't found term '#{source_term}: #{target_term}' in '#{@glossary}'"
      end
    end

    def delete(source_term, target_term)
      raise GlossaryNotFound unless File.exist?(source_path)

      glossary_source = GlossarySource.load_glossary_source(source_path)
      target_index = find_term_index(glossary_source, source_term, target_term)
      unless target_index
        raise TermError, "Can't found term '#{source_term} #{target_term}' in '#{@glossary}'" unless target_index
      end

      glossary_source.delete_at(target_index)
      dump_glossary_source(glossary_source)
    end

    def delete_all(source_term, force=false)
      raise GlossaryNotFound unless File.exist?(source_path)

      glossary_source = GlossarySource.load_glossary_source(source_path)
      delete_candidates = target_terms(glossary_source, source_term)
      if delete_candidates.empty?
        raise TermError, "Can't found term '#{source_term} in '#{@glossary}'"
      end

      if delete_candidates.size == 1 || force
        glossary_source.delete_if{|term| term['source_term'] == source_term }
        dump_glossary_source(glossary_source)
      else
        raise TermError, "There are duplicate terms in glossary.\n" +
          "If you really want to delete, please put `loga delete [SOURCE_TERM] --force`\n" +
          " or `loga delete [SOURCE_TERM] [TARGET_TERM]`"
      end
    end

    def source_path
      if @source_path
        @source_path
      else
        fname = [@glossary, @source_language, @target_language].join(".")
        @source_path = File.join(@logaling_home, "projects", @glossary, "glossary", "#{fname}.yml")
      end
    end

    private
    def build_term(source_term, target_term, note)
      note ||= ''
      {'source_term' => source_term, 'target_term' => target_term, 'note' => note}
    end

    def rebuild_term(current, source_term, target_term, note)
      if current['target_term'] != target_term && (note.nil? || note == "")
        note = current['note']
      end
      target_term = current['target_term'] if target_term == ""
      build_term(source_term, target_term, note)
    end

    def find_term_index(glossary_source, source_term, target_term='')
      glossary_source.find_index do |term|
        if target_term.empty?
          term['source_term'] == source_term
        else
          term['source_term'] == source_term && term['target_term'] == target_term
        end
      end
    end

    def target_terms(glossary_source, source_term)
      glossary_source.select {|term| term['source_term'] == source_term }
    end

    def dump_glossary_source(glossary_source)
      File.open(source_path, "w") do |f|
        f.puts(glossary_source.to_yaml)
      end
    end
  end
end
