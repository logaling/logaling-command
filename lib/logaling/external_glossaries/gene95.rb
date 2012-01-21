# Copyright (C) 2012 Koji SHIMADA
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
require 'zlib'

module Logaling
  class Gene95 < ExternalGlossary
    description     'GENE95 Dictionary (http://www.namazu.org/~tsuchiya/sdic/data/gene.html)'
    source_language 'en'
    target_language 'ja'

    def convert
      CSV.generate do |csv|
        puts "downloading gene95 dictionary..."
        Zlib::GzipReader.open(open('http://www.namazu.org/~tsuchiya/sdic/data/gene95.tar.gz')) do |gz|
          contents = false
          puts "importing gene95 dictionary..."
          gz.readlines.map{|l| l.encode("UTF-8", "CP932", undef: :replace, replace: '').strip }.each_slice(2) do |source, target|
            if contents
              csv << [ source.split("    ").map(&:strip)[0], target ]
            else
              contents = true
            end
          end
        end
      end
    end
  end
end
