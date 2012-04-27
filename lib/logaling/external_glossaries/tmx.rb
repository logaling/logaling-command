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

require 'open-uri'
require 'nokogiri'
module Logaling
  class Tmx < ExternalGlossary
    description     'TMX 1.4b formatted glossary (http://www.gala-global.org/oscarStandards/tmx/)'
    source_language 'en'
    target_language 'ja'
    output_format   'csv'

    private
    def convert_to_csv(csv, glossary_info)
      doc = ::Nokogiri::XML(open(glossary_info[:url], "r"))
      doc.search('//tu').each do |tu|
        original = ""
        translation = ""
        notes = []
        tu.children.each do |tuv|
          if tuv.name == "tuv"
            lang = convert_language_code_iso_639(tuv["lang"])
            if lang == glossary_info[:source_language]
              tuv.children.each do |child|
                original = child.text.strip if child.name == "seg"
                notes << child.text.strip if child.name == "note"
              end
            elsif lang == glossary_info[:target_language]
              tuv.children.each do |child|
                translation = child.text.strip if child.name == "seg"
                notes << child.text.strip if child.name == "note"
              end
            end
          end
        end
        csv << [original, translation, notes.join(" | ")] if original && translation
      end
    end

    def convert_language_code_iso_639(code)
      # use two-letter codes
      code.downcase.sub(/-.*\z/, "")
    end
  end
end
