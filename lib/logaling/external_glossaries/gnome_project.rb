#    Copyright (C) 2001  Miho SUZUKI
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'open-uri'
require 'nokogiri'

module Logaling
  class GnomeProject < ExternalGlossary
    description     'GNOME Translation Project Ja (http://live.gnome.org/TranslationProjectJa)'
    source_language 'en'
    target_language 'ja'

    def convert
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://www.gnome.gr.jp/l10n/trans-terms.html", "r"))
        doc.css('table tr')[1..-1].each do |tr|
          csv << [tr.children[0].text, tr.children[1].text]
        end
      end
    end
  end
end
