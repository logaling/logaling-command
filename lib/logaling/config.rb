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
      def load(config_path)
        config = new
        config.load(config_path)
        config
      end
    end

    def initialize(config={})
      @config = config
    end

    def check_required_option(required={})
      required.each do |required_option, message|
        raise(Logaling::CommandFailed, message) unless @config[required_option]
      end
    end

    def merge(config)
      keys.each do |key|
        @config[key] = config[key] if config[key]
      end
    end

    def load(config_path=nil)
      if config_path && File.exist?(config_path)
        File.readlines(config_path).map{|l| l.chomp.split " "}.each do |option|
          key = option[0].sub(/^[\-]{2}/, "")
          value = option[1]
          @config[key] = value
        end
      end
    end

    def add(key, value)
      raise Logaling::CommandFailed, "#{key} is unsupported option" unless support?(key)
      merge(key => value)
    end

    def save(config_path)
      File.open(config_path, 'w') do |fp|
        keys.each do |key|
          fp.puts "--#{key} #{@config[key]}" if @config[key]
        end
      end
    end

    def glossary
      @config["glossary"]
    end

    def source_language
      @config["source-language"]
    end

    def target_language
      @config["target-language"]
    end

    private
    def keys
      %w(glossary source-language target-language)
    end

    def support?(key)
      keys.include?(key)
    end
  end
end
