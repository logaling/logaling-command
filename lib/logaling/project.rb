# Copyright (C) 2012  Miho SUZUKI
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
  class Project
    class << self
      def find_dotfile(base_dir=Dir.pwd)
        searched_path = []
        dir = base_dir
        loop do
          path = File.join(dir, '.logaling')
          if File.exist?(path)
            return path
          else
            unless Pathname.new(dir).root?
              searched_path << dir
              dir = File.dirname(dir)
            else
              raise Logaling::ProjectNotFound, "Can't found .logaling in #{searched_path}"
            end
          end
        end
      end
    end
    attr_reader :path, :repository

    def initialize(path, repository=nil)
      @path = path
      @repository = repository
    end

    def name
      File.basename(@path)
    end

    def find_glossary(source_language, target_language)
      Logaling::Glossary.new(name, source_language, target_language, self)
    end

    def glossary_source_path
      File.join(@path, "glossary")
    end

    def glossary_db_path
      @repository.logaling_db_home
    end

    def glossary_sources
      all_glossary_source_path = Dir.glob(File.join(glossary_source_path, "*"))
      all_glossary_source_path.map do |source_path|
        name, source_language, target_language, type = File.basename(source_path).split(/\./)
        GlossarySource.create(source_path, find_glossary(source_language, target_language))
      end
    end
  end

  class ImportedProject < Project
    def name
      File.basename(@path).split(/\./).first
    end

    def glossary_sources
      name, source_language, target_language, type = File.basename(@path).split(/\./)
      [GlossarySource.create(@path, find_glossary(source_language, target_language))]
    end
  end
end
