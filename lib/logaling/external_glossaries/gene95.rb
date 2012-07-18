# Copyright (C) 2012  Koji SHIMADA
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
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
require 'rubygems/package'

module Logaling
  class Gene95 < ExternalGlossary
    description     'GENE95 Dictionary'
    url             'http://www.namazu.org/~tsuchiya/sdic/data/gene.html'
    source_language 'en'
    target_language 'ja'
    output_format   'csv'

    private
    def convert_to_csv(csv)
      puts "downloading gene95 dictionary..."
      url = 'http://www.namazu.org/~tsuchiya/sdic/data/gene95.tar.gz'
      Zlib::GzipReader.open(open(url)) do |gz|
        puts "importing gene95 dictionary..."

        Gem::Package::TarReader.new(gz) do |tar|
          tar.each do |entry|
            case entry.full_name
            when "gene.txt"
              lines = StringIO.new(entry.read).each_line

              2.times { lines.next } # skip header

              preprocessed_lines = lines.map.map do |line|
                line.encode("UTF-8", "CP932",
                            undef: :replace, replace: '').chomp
              end

              preprocessed_lines.each_slice(2) do |source, target|
                csv << [source.sub(/(    .*)/, ''), target]
              end
            else
              # ignore
            end
          end
        end
      end
    end
  end
end
