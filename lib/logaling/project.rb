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

    def initialize(relative_path, repository=nil)
      @path = relative_path
      @repository = repository
    end

    def name
      File.basename(@path)
    end

    def glossary(source_language, target_language)
      Logaling::Glossary.new(name, source_language, target_language, self)
    end

    def glossary_source_path
      File.join(@repository.expand_path(@path), "glossary")
    end
    alias_method :source_directory_path, :glossary_source_path

    # relative_path_from_logaling_home みたいな名前でGlossarySourceにある方が良いかも...
    def relative_path(glossary_source_file_name)
      source_path = File.join(source_directory_path, glossary_source_file_name)
      @repository.relative_path(source_path)
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
      all_glossary_source_path.map do |source_path_full|
        name, source_language, target_language, type = File.basename(source_path_full).split(/\./)
        source_path = @repository.relative_path(source_path_full)
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

    def type
      self.class.to_s.sub('Logaling::', '')
    end

    def same?(project)
      name == project.name
    end

    private
    def all_glossary_source_path
      Dir.glob(File.join(glossary_source_path, "*"))
    end
  end

  class FileBasedProject < Project
    def name
      File.basename(@path).split(/\./).first
    end

    def glossary_sources
      name, source_language, target_language, type = File.basename(@path).split(/\./)
      [GlossarySource.create(@path, glossary(source_language, target_language))]
    end

    def has_glossary?(source_language, target_language)
      glossary_source_language, glossary_target_language = File.basename(@path).split(/\./)[1..2]
      glossary_source_language == source_language && glossary_target_language == target_language
    end

    def absolute_path
      @repository.expand_path(@path)
    end
    alias_method :glossary_source_path, :absolute_path

    def normal_project?
      false
    end

    def source_directory_path
      File.dirname(glossary_source_path)
    end
  end

  class ImportedProject < FileBasedProject
    def imported?
      true
    end
  end

  class PersonalProject < FileBasedProject
    class << self
      def create(relative_root_path, glossary_name, source_language, target_language, repository=nil)
        project_name = [glossary_name, source_language, target_language, 'yml'].join('.')
        project_path = File.join(relative_root_path, project_name)
        project = PersonalProject.new(project_path, repository)
        project.initialize_glossary(source_language, target_language)
        project
      end

      def remove(relative_root_path, glossary_name, source_language, target_language, repository)
        project_name = [glossary_name, source_language, target_language, 'yml'].join('.')
        project_path = File.join(relative_root_path, project_name)
        project = PersonalProject.new(project_path, repository)
        FileUtils.rm_rf(repository.expand_path(project_path), :secure => true)
        project
      end
    end

    def initialize_glossary(source_language, target_language)
      glossary(source_language, target_language).initialize_glossary_source
    end

    def personal?
      true
    end
  end
end
