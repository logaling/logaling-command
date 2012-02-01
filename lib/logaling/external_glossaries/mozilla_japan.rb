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
  class MozillaJapan < ExternalGlossary
    description     'Mozilla Japan (http://www.mozilla-japan.org/jp/l10n/term/l10n.html)'
    source_language 'en'
    target_language 'ja'
    output_format   'csv'

    private
    def convert_to_csv(csv)
      url = 'http://www.mozilla-japan.org/jp/l10n/term/l10n.html'
      doc = ::Nokogiri::HTML(open(url, "r"))
      doc.encoding = "UTF-8"
      doc.search(".obsolete").remove
      doc.search(".relate").remove
      doc.css("dl[@class='terminology en-ja']").each do |dl|
        dl.children.each_slice(2) do |dt, dd|
          dd.text.split("|").each do |ddt|
            ddt = ddt.gsub(/\s/, '')
            unless ddt.empty?
              csv << [dust_to_tilda(dt.text), dust_to_tilda(ddt)]
            end
          end
        end
      end
    end

    def dust_to_tilda(txt)
      txt.gsub("\xEF\xBF\xBD", "\xE3\x80\x9C")
    end
  end
end
