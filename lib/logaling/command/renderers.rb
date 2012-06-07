module Logaling::Command
  module Renderers
    class TermRenderer
      def initialize(term, repository, config, options)
        @term = term
        @repository = repository
        @config = config
        @options = options
      end

      def render(out); end

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
        return term if snipped_term.empty? || @options["no-color"]
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

      def render(out)
        format = [target_term, note, glossary_name].compact.join("\t")
        out.printf("  %-#{@max_str_size+10}s %s\n", source_term, format)
      end

      def note
        note_string = super
        "# #{note_string}" if note_string
      end
    end

    class TermCsvRenderer < TermRenderer
      def render(out)
        items = [source_term, target_term, note,
                 @config.source_language, @config.target_language]
        out.print(CSV.generate {|csv| csv << items})
      end
    end

    class TermJsonRenderer < TermRenderer
      attr_accessor :index, :last_index

      def initialize(term, repository, config, options)
        super
        @index = 0
        @last_index = 0
      end

      def render(out)
        first_line? ? out.puts("[") : out.puts(",")
        record = {
          :source => source_term, :target => target_term, :note => note,
          :source_language => @config.source_language,
          :target_language => @config.target_language
        }
        out.print JSON.pretty_generate(record)
        out.puts("\n]") if last_line?
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
