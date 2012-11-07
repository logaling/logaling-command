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

      def find_path(source_path)
        if source_path =~ /(.+\/projects\/[^\/]+).+/
          $1
        else
          source_path
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

    def glossary(source_language, target_language)
      Logaling::Glossary.new(name, source_language, target_language, self)
    end

    def glossary_source_path
      File.join(@path, "glossary")
    end

    def glossary_db_path
      @repository.logaling_db_home
    end

    def glossaries
      glossaries = all_glossary_source_path.map do |source_path|
        name, source_language, target_language, type = File.basename(source_path).split(/\./)
        glossary(source_language, target_language)
      end
      glossaries.uniq{|glossary| glossary.to_s }
    end

    def glossary_sources
      all_glossary_source_path.map do |source_path|
        name, source_language, target_language, type = File.basename(source_path).split(/\./)
        GlossarySource.create(source_path, glossary(source_language, target_language))
      end
    end

    def has_glossary?(source_language, target_language)
      glossaries.any? {|glossary| glossary.to_s == [name, source_language, target_language].join('.') }
    end

    def imported?
      false
    end

    def personal?
      false
    end

    def normal_project?
      true
    end

    private
    def all_glossary_source_path
      Dir.glob(File.join(glossary_source_path, "*"))
    end
  end

  class ImportedProject < Project
    def name
      File.basename(@path).split(/\./).first
    end

    def glossary_sources
      name, source_language, target_language, type = File.basename(@path).split(/\./)
      [GlossarySource.create(@path, glossary(source_language, target_language))]
    end

    def glossary_source_path
      File.dirname(@path)
    end

    def imported?
      true
    end

    def normal_project?
      false
    end
  end

  class PersonalProject < Project
    class << self
      def create(root_path, glossary_name, source_language, target_language, repository=nil)
        project_name = [glossary_name, source_language, target_language, 'yml'].join('.')
        project_path = File.join(root_path, project_name)
        project = PersonalProject.new(project_path, repository)
        project.initialize_glossary(source_language, target_language)
        project
      end

      def remove(root_path, glossary_name, source_language, target_language, repository=nil)
        project_name = [glossary_name, source_language, target_language, 'yml'].join('.')
        project_path = File.join(root_path, project_name)
        project = PersonalProject.new(project_path, repository)
        FileUtils.rm_rf(project_path, :secure => true)
        project
      end
    end

    def name
      File.basename(@path).split(/\./).first
    end

    def glossary_sources
      name, source_language, target_language, type = File.basename(@path).split(/\./)
      [GlossarySource.create(@path, glossary(source_language, target_language))]
    end

    def glossary_source_path
      File.dirname(@path)
    end

    def initialize_glossary(source_language, target_language)
      glossary(source_language, target_language).initialize_glossary_source
    end

    def personal?
      true
    end

    def normal_project?
      false
    end
  end
end
