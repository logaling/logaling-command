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

module Logaling::Command
  module Renderers
    class TermRenderer
      def initialize(term, repository, config, options)
        @term = term
        @repository = repository
        @config = config
        @options = options
      end

      def render(output); end

      def glossary_name
        if @repository.glossary_counts > 1
          if @term[:glossary_name] == @config.glossary
            @term[:glossary_name].foreground(:white).background(:green)
          else
            @term[:glossary_name]
          end
        else
          ""
        end
      end

      def note
        @term[:note].to_s unless @term[:note].empty?
      end

      def source_term
        extract_keyword_and_coloring(@term[:snipped_source_term], @term[:source_term])
      end

      def target_term
        extract_keyword_and_coloring(@term[:snipped_target_term], @term[:target_term])
      end

      private
      def extract_keyword_and_coloring(snipped_term, term)
        return term if @options["no-color"]
        build_term_string_from_snippets(snipped_term)
      end

      def build_term_string_from_snippets(snippets)
        snippets.map{|snippet| decorate_snippet(snippet) }.join
      end

      def decorate_snippet(snippet)
        keyword?(snippet) ? snippet[:keyword].bright : snippet
      end

      def keyword?(snippet)
        snippet.is_a?(Hash)
      end
    end

    class TermDefaultRenderer < TermRenderer
      attr_accessor :max_str_size

      def initialize(term, repository, config, options)
        super
        @max_str_size = 0
      end

      def render(output)
        format = [target_term, note, glossary_name].compact.join("\t")
        output.printf("  %-#{@max_str_size+10}s %s\n", source_term, format)
      end

      def note
        note_string = super
        "# #{note_string}" if note_string
      end
    end

    class TermCsvRenderer < TermRenderer
      def render(output)
        items = [source_term, target_term, note,
                 @config.source_language, @config.target_language]
        output.print(CSV.generate {|csv| csv << items})
      end
    end

    class TermJsonRenderer < TermRenderer
      attr_accessor :index, :last_index

      def initialize(term, repository, config, options)
        super
        @index = 0
        @last_index = 0
      end

      def render(output)
        first_line? ? output.puts("[") : output.puts(",")
        record = {
          :source => source_term, :target => target_term, :note => note,
          :source_language => @config.source_language,
          :target_language => @config.target_language
        }
        output.print JSON.pretty_generate(record)
        output.puts("\n]") if last_line?
      end

      private
      def first_line?
        @index == 0
      end
      def last_line?
        @index == @last_index-1
      end
    end
  end
end
