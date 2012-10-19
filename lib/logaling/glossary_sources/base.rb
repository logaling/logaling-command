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

module Logaling
  module GlossarySources
    class Base
      attr_reader :source_path, :glossary

      def initialize(source_path, glossary)
        @source_path = source_path
        @glossary = glossary
      end

      def eql?(other)
        return false unless self.class == other.class
        @source_path == other.source_path
      end

      def hash
        @source_path.hash
      end

      def mtime
        File.mtime(@source_path)
      end

      def belongs_to_personal?
        @source_path =~ /.+\/personal\/.+/ ? true : false
      end

      def belongs_to_project?
        @source_path =~ /.+\/projects\/.+/ ? true : false
      end

      def glossary_name
        File.basename(@source_path).split(".", 2)[0]
      end

      def project_name
        @source_path =~ /.+\/projects\/([^\/]+).+/ ? $1 : nil
      end
    end
  end
end
