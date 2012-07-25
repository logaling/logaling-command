# -*- coding: utf-8 -*-
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

require 'nokogiri'

module Logaling
  class ItilJapanese < ExternalGlossary
    description     'ITIL Japanese 2011 Glossary'
    url             'http://www.itil-officialsite.com/InternationalActivities/ITILGlossaries_2.aspx'
    source_language 'en'
    target_language 'ja'
    output_format   'csv'

    private
    def convert_to_csv(csv)
      # open local html file because web resources are PDF or MS Word file...
      file_path = File.join(File.dirname(__FILE__), "resources", "ITIL_2011_Japanese_Glossary_v1.0.html")
      doc = Nokogiri::HTML(File.open(file_path), nil, "utf-8")
      abbreviation = false
      doc.css('table tr')[1..-1].each do |tr|
        p = tr.children[0].css('p').first
        abbreviation = true and next if p['class'] == 'WLBody'

        source_term = format_text(tr.children[0].text)
        unless abbreviation
          target_term = format_text(tr.children[2].text)
        else
          target_term = sprintf("%s %s", format_text(tr.children[4].text), format_text(tr.children[6].text))
        end
        csv << [source_term, target_term]
      end
    end

    def format_text(text)
      text.strip.gsub(/(\r\n|\r|\n)/, "").gsub(/\s+/, " ")
    end
  end
end
