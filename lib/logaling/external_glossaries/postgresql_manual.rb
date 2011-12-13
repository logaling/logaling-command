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

require 'open-uri'
require 'nokogiri'

module Logaling
  class PostgresqlManual < ExternalGlossary
    description     'PostgreSQL7.1 Manual (http://osb.sraoss.co.jp/PostgreSQL/Manual/)'
    source_language 'en'
    target_language 'ja'

    def convert
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://osb.sraoss.co.jp/PostgreSQL/Manual/word.html", "r:iso-2022-jp").read.encode("utf-8"))
        doc.css('table table tr')[2..-1].each do |tr|
          if tr.children[2]
            csv << [tr.children[2].text, tr.children[4].text]
          end
        end
      end
    end
  end
end
