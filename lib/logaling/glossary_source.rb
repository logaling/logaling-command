# -*- coding: utf-8 -*-
#
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

require "logaling/glossary_sources/glossary_yaml_source"
require "logaling/glossary_sources/glossary_csv_source"
require "logaling/glossary_sources/glossary_tsv_source"

module Logaling
  class GlossarySource
    def self.create(source_path, glossary)
      case File.extname(source_path)
      when ".csv"
        GlossarySources::GlossaryCsvSource.new(source_path, glossary)
      when ".tsv"
        GlossarySources::GlossaryTsvSource.new(source_path, glossary)
      when ".yml"
        GlossarySources::GlossaryYamlSource.new(source_path, glossary)
      end
    end
  end
end
