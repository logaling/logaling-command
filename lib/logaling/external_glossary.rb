require 'active_support/inflector'

class Logaling::ExternalGlossary
  class << self
    def load
      Dir[File.join(File.dirname(__FILE__), "external_glossary", "*.rb")].each do |file|
        require file
      end
    end

    def inherited(subclass)
      external_glossaries << subclass
    end

    def get(external_glossary)
      external_glossaries.detect{|c| c.inspect.include? external_glossary.camelize }.new
    end

    def external_glossaries
      @@external_glossaries ||= []
    end
  end

  def import; end
end
