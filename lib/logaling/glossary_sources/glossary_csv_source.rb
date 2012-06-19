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

require "logaling/glossary_sources/base"
require "csv"

module Logaling::GlossarySources
  class GlossaryCsvSource < Base
    def load
      glossary_source = []
      CSV.open(source_path, "r:utf-8",  {:col_sep => ','}) do |csv|
        csv.each do |row|
          glossary_source << {"source_term" => row[0], "target_term" => row[1], "note" => ""} if row.size >= 2
        end
      end
      glossary_source
    end
  end
end
