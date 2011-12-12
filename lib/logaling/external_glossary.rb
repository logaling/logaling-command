require 'active_support/inflector'

class Logaling::ExternalGlossary
  class << self
    def load
      Dir[File.join(File.dirname(__FILE__), "external_glossaries", "*.rb")].each do |file|
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

    def name
      self.to_s.underscore.gsub(/.*\//,'')
    end

    def description val=nil
      @description ||= val
    end

    def source_language val=nil
      @source_language ||= val
    end

    def target_language val=nil
      @target_language ||= val
    end
  end

  def import
    File.open(import_file_name, "w") {|f| f.write(self.convert) }
  end

  private
  def import_file_name
    [self.class.name, self.class.source_language, self.class.target_language, 'csv'].join('.')
  end
end
