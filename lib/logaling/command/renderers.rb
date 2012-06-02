module Logaling::Command
  module Renderers
    class TermRenderer
      attr_accessor :max_str_size

      def initialize(term, repository, config, options)
        @term = term
        @repository = repository
        @config = config
        @options = options
        @max_str_size = 0
      end

      def render
        unless note
          format = target_term + "\t" + glossary_name
        else
          format = target_term + "\t# " + note + "\t" + glossary_name
        end
        printf("  %-#{@max_str_size+10}s %s\n", source_term, format)
      end

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
        display_string = snipped_term.map do |word|
          word.is_a?(Hash) ? word[:keyword].bright : word
        end
        display_string.join
      end
    end

    class TermCsvRenderer < TermRenderer
      def render
        items = [source_term, target_term, note,
                 @config.source_language, @config.target_language]
        print(CSV.generate {|csv| csv << items})
      end
    end

    class TermJsonRenderer < TermRenderer
      attr_accessor :index, :last_index

      def initialize(term, repository, config, options)
        super
        @index = 0
        @last_index = 0
      end

      def render
        puts("[") if @index == 0
        puts(",") if @index > 0
        record = {
          :source => source_term, :target => target_term, :note => note,
          :source_language => @config.source_language,
          :target_language => @config.target_language
        }
        print JSON.pretty_generate(record)
        puts("\n]") if @index == @last_index-1
      end
    end
  end
end
