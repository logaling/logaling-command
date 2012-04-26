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

    def list
      external_glossaries
    end

    def get(external_glossary)
      external_glossaries.detect{|c| c.inspect.include? external_glossary.camelize }.new
    rescue NoMethodError
      raise Logaling::ExternalGlossaryNotFound
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

    def output_format(*args)
      if args.empty?
        @output_format ||= "csv"
      else
        @output_format = args.first
      end
    end
  end

  def import(glossary_info=nil)
    File.open(import_file_name(glossary_info), "w") do |output|
      output_format = self.class.output_format
      output_format = output_format.to_s if output_format.is_a?(Symbol)
      case output_format
      when "csv"
        if glossary_info
          convert_to_csv(CSV.new(output), glossary_info)
        else
          convert_to_csv(CSV.new(output))
        end
      else
        raise UnsupportedFormat, "unsupported format: <#{output_format}>"
      end
    end
  end

  private
  def import_file_name(glossary_info=nil)
    if glossary_info
      glossary_info[:name] ||= self.class.name
      glossary_info[:source_language] ||= self.class.source_language
      glossary_info[:target_language] ||= self.class.target_language

      [glossary_info[:name], glossary_info[:source_language],
       glossary_info[:target_language], self.class.output_format].join('.')
    else
      [self.class.name, self.class.source_language,
       self.class.target_language, self.class.output_format].join('.')
    end
  end
end
