# -*- coding: utf-8 -*-
#
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

module Logaling
  class FreebsdJpman < ExternalGlossary
    description     'FreeBSD jpman'
    url             'http://www.jp.freebsd.org/man-jp/'
    source_language 'en'
    target_language 'ja'
    output_format   'csv'

    private
    def convert_to_csv(csv)
      url = 'http://www.jp.freebsd.org/man-jp/docs/wordlist.txt'
      open(url,'r:iso-2022-jp') do |f|
        f.each_line.map{|l| l.encode("utf-8")}.each do |line|
          next if line =~ /^(#|\t)/
          csv << line.split(/\t+| {5}/, 2).map(&:strip)
        end
      end
    end
  end
end
