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
  class Config
    class << self
      def add(config_path, key, value)
        raise Logaling::CommandFailed, "#{key} is unsupported option" unless support?(key)

        config = load_config(config_path)
        config = merge_options({key => value}, config)
        Config.new(config).write_config(config_path)
      end

      def load_config_and_merge_options(project_config_path, global_config_path, options)
        config_list ||= {}
        find_config(project_config_path, global_config_path).each{|type, path| config_list[type] = load_config(path)}
        global_config = config_list["global_config"] ? config_list["global_config"] : {}
        project_config = config_list["project_config"] ? config_list["project_config"] : {}

        config = merge_options(project_config, global_config)
        config = merge_options(options, config)

        Config.new(config)
      end

      private
      def support?(key)
        support_keys = %w(glossary source-language target-language)
        support_keys.include?(key)
      end

      def merge_options(options, secondary_options)
        config ||={}
        config["glossary"] = options["glossary"] ? options["glossary"] : secondary_options["glossary"]
        config["source-language"] = options["source-language"] ? options["source-language"] : secondary_options["source-language"]
        config["target-language"] = options["target-language"] ? options["target-language"] : secondary_options["target-language"]
        config
      end

      def find_config(project_config_path, global_config_path)
        config ||= {}
        if project_config_path
          config["project_config"] = project_config_path
        else
          config["project_config"] = global_config_path
        end
        config["global_config"] = global_config_path if global_config_path
        config
      end

      def load_config(config_path=nil)
        config ||= {}
        if config_path
          File.readlines(config_path).map{|l| l.chomp.split " "}.each do |option|
            key = option[0].sub(/^[\-]{2}/, "")
            value = option[1]
            config[key] = value
          end
        end
        config
      end
    end
    attr_reader :glossary, :source_language, :target_language

    def initialize(config)
      @glossary = config["glossary"]
      @source_language = config["source-language"]
      @target_language = config["target-language"]
      @config = config
    end

    def check_required_option(required={})
      required.each do |required_option, message|
        raise(Logaling::CommandFailed, message) unless @config[required_option]
      end
    end

    def write_config(config_path)
      File.open(config_path, 'w') do |fp|
        fp.puts "--glossary #{@glossary}" if @glossary
        fp.puts "--source-language #{@source_language}" if @source_language
        fp.puts "--target-language #{@target_language}" if @target_language
      end
    end
  end
end
