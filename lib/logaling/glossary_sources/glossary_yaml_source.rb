# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Koji SHIMADA <koji.shimada@enishi-tech.com>
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

require "logaling/glossary_sources/base"
begin
  require 'psych'
rescue LoadError => e
  raise LoadError unless e.message =~ /psych/
  puts "please install psych first."
end
require "yaml"
require "fileutils"

module Logaling::GlossarySources
  class GlossaryYamlSource < Base
    def load
      YAML::load_file(source_path) || []
    rescue TypeError
      []
    end

    def add(source_term, target_term, note)
      initialize_source unless File.exist?(source_path)

      glossary_source = self.load
      glossary_source << build_term(source_term, target_term, note)
      dump_glossary_source(glossary_source)
    rescue
      raise Logaling::GlossaryNotFound
    end

    def update(source_term, target_term, new_target_term, note)
      raise Logaling::GlossaryNotFound unless File.exist?(source_path)

      glossary_source = self.load
      target_index = find_term_index(glossary_source, source_term, target_term)
      if target_index
        glossary_source[target_index] = rebuild_term(glossary_source[target_index], source_term, new_target_term, note)
        dump_glossary_source(glossary_source)
      else
        raise Logaling::TermError, "Can't found term '#{source_term}: #{target_term}' in '#{@glossary.name}'"
      end
    end

    def delete(source_term, target_term)
      raise Logaling::GlossaryNotFound unless File.exist?(source_path)

      glossary_source = self.load
      target_index = find_term_index(glossary_source, source_term, target_term)
      unless target_index
        raise Logaling::TermError, "Can't found term '#{source_term} #{target_term}' in '#{@glossary.name}'" unless target_index
      end

      glossary_source.delete_at(target_index)
      dump_glossary_source(glossary_source)
    end

    def delete_all(source_term, force=false)
      raise Logaling::GlossaryNotFound unless File.exist?(source_path)

      glossary_source = self.load
      delete_candidates = target_terms(glossary_source, source_term)
      if delete_candidates.empty?
        raise Logaling::TermError, "Can't found term '#{source_term} in '#{@glossary.name}'"
      end

      if delete_candidates.size == 1 || force
        glossary_source.delete_if{|term| term['source_term'] == source_term }
        dump_glossary_source(glossary_source)
      else
        raise Logaling::TermError, "There are duplicate terms in glossary.\n" +
          "If you really want to delete, please put `loga delete [SOURCE_TERM] --force`\n" +
          " or `loga delete [SOURCE_TERM] [TARGET_TERM]`"
      end
    end

    def initialize_source
      dump_glossary_source([])
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
        f << YAML.dump(glossary_source)
      end
    end
  end
end
