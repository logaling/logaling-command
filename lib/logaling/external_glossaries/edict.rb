# Copyright (C) 2012  Koji SHIMADA <koji.shimada@enishi-tech.com>
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
require 'stringio'

module Logaling
  class Edict < ExternalGlossary
    description     'The EDICT Dictionary File (http://www.csse.monash.edu.au/~jwb/edict.html)'
    source_language 'ja'
    target_language 'en'
    output_format   'csv'

    private
    def convert_to_csv(csv)
      puts "downloading edict file..."
      url = 'http://ftp.monash.edu.au/pub/nihongo/edict.gz'
      Zlib::GzipReader.open(open(url)) do |gz|
        puts "importing edict file..."

        lines = StringIO.new(gz.read).each_line

        lines.next # skip header

        preprocessed_lines = lines.map do |line|
          line.encode("UTF-8", "EUC-JP").chomp
        end

        preprocessed_lines.each do |line|
          source, target = line.split('/', 2)
          source = source.strip
          csv << [source, target]
        end
      end
    end
  end
end
