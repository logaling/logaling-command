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

require 'thor'
require 'rainbow'
require "logaling/repository"
require "logaling/glossary"

module Logaling::Command
  LOGALING_CONFIG = '.logaling'

  class Application < Thor

    def initialize(*args)
      super
      @config = load_config_and_merge_options()
      @source_language = @config["source-language"]
      @target_language = @config["target-language"]
      @repository = Logaling::Repository.new(LOGALING_HOME)
    end

    map '-a' => :add,
        '-d' => :delete,
        '-u' => :update,
        '-l' => :lookup,
        '-i' => :import,
        '-n' => :new,
        '-r' => :register,
        '-U' => :unregister,
        '-L' => :list,
        '-s' => :show,
        '-v' => :version

    class_option "glossary",        type: :string, aliases: "-g"
    class_option "source-language", type: :string, aliases: "-S"
    class_option "target-language", type: :string, aliases: "-T"
    class_option "logaling-home",   type: :string, aliases: "-h"

    desc 'new [PROJECT NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE(optional)]', 'Create .logaling'
    method_option "no-register", type: :boolean, default: false
    def new(project_name, source_language, target_language=nil)
      unless File.exist?(LOGALING_CONFIG)
        FileUtils.mkdir_p(File.join(LOGALING_CONFIG, "glossary"))
        config = {"glossary" => project_name, "source-language" => source_language}
        config["target-language"] = target_language if target_language
        write_config(File.join(LOGALING_CONFIG, "config"), config)

        register unless options["no-register"]
        say "Successfully created #{LOGALING_CONFIG}"
      else
        say "#{LOGALING_CONFIG} already exists."
      end
    end

    desc 'import', 'Import external glossary'
    method_option "list", type: :boolean, default: false
    def import(external_glossary=nil)
      require "logaling/external_glossary"
      Logaling::ExternalGlossary.load
      if options["list"]
        Logaling::ExternalGlossary.list.each {|glossary| say "#{glossary.name.bright} : #{glossary.description}" }
      else
        @repository.import(Logaling::ExternalGlossary.get(external_glossary))
      end
    rescue Logaling::ExternalGlossaryNotFound
      say "'#{external_glossary}' can't find in import list."
      say "Try 'loga import --list' and confirm import list."
    end

    desc 'register', 'Register .logaling'
    def register
      logaling_path = find_dotfile

      required_options = {"glossary" => "input glossary name '-g <glossary name>'"}
      config = load_config_and_merge_options(required_options)

      @repository.register(logaling_path, config["glossary"])
      @repository.index
      say "#{config['glossary']} is now registered to logaling."
    rescue Logaling::CommandFailed => e
      say e.message
      say "Try 'loga new' first."
    rescue Logaling::GlossaryAlreadyRegistered => e
      say "#{config['glossary']} is already registered."
    end

    desc 'unregister', 'Unregister .logaling'
    def unregister
      required_options = {"glossary" => "input glossary name '-g <glossary name>'"}
      config = load_config_and_merge_options(required_options)

      @repository.unregister(config["glossary"])
      @repository.index
      say "#{config['glossary']} is now unregistered."
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "#{config['glossary']} is not yet registered."
    end

    desc 'config [KEY] [VALUE] [--global(optional)]', 'Set config.'
    method_option "global", type: :boolean, default: false
    def config(key, value)
      support_keys = %w(glossary source-language target-language)
      raise Logaling::CommandFailed, "#{key} is unsupported option" unless support_keys.include?(key)

      config_path = options["global"] ? File.join(LOGALING_HOME, "config") : File.join(find_dotfile, "config")
      FileUtils.touch(config_path) unless File.exist?(config_path)

      config = load_config(config_path)
      config = merge_options({key => value}, config)
      write_config(config_path, config)
      say "Successfully set config."
    rescue Logaling::CommandFailed => e
      say e.message
    end

    desc 'add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]', 'Add term to glossary.'
    def add(source_term, target_term, note='')
      config = load_config_and_merge_options
      @repository.index

      if repository.bilingual_pair_exists?(source_term, target_term, config["glossary"])
        raise Logaling::TermError, "term '#{source_term}: #{target_term}' already exists in '#{config["glossary"]}'"
      end

      glossary.add(source_term, target_term, note)
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    end

    desc 'delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]', 'Delete term.'
    method_option "force", type: :boolean, default: false
    def delete(source_term, target_term=nil)
      if target_term
        glossary.delete(source_term, target_term)
      else
        glossary.delete_all(source_term, options["force"])
      end
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    end

    desc 'update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM] [NOTE(optional)]', 'Update term.'
    def update(source_term, target_term, new_target_term, note='')
      config = load_config_and_merge_options
      @repository.index

      if @repository.bilingual_pair_exists_and_has_same_note?(source_term, new_target_term, note, config["glossary"])
        raise Logaling::TermError, "term '#{source_term}: #{new_target_term}' already exists in '#{config["glossary"]}'"
      end

      glossary.update(source_term, target_term, new_target_term, note)
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    end

    desc 'lookup [TERM]', 'Lookup terms.'
    method_option "output", type: :string, default: "terminal"
    def lookup(source_term)
      @repository.index
      terms = @repository.lookup(source_term, @source_language, @target_language,
                                @config["glossary"])
      unless terms.empty?
        max_str_size = terms.map{|term| term[:source_term].size}.sort.last
        run_pager
        terms.each_with_index do |term, i|
          source_string = extract_source_string_and_coloring(term)
          target_string = term[:target_term].bright
          note = term[:note].to_s unless term[:note].empty?
          if @repository.glossary_counts > 1
            glossary_name = term[:glossary_name]
            if term[:glossary_name] == @config["glossary"]
              glossary_name = glossary_name.foreground(:white).background(:green)
            end
          end
          printer(source_string, target_string, note,
                  glossary_name, max_str_size, i, terms.length)
        end
      else
        "source-term <#{source_term}> not found"
      end
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    end

    desc 'version', 'Show version.'
    def version
      say "logaling-command version #{Logaling::Command::VERSION}"
    end

    desc 'show', 'Show terms in glossary.'
    def show
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      config = load_config_and_merge_options(required_options)
      @repository.index
      terms = @repository.show_glossary(config["glossary"], config["source-language"], config["target-language"])
      unless terms.empty?
        run_pager
        max_str_size = terms.map{|term| term[:source_term].size}.sort.last
        terms.each do |term|
          target_string = "#{term[:target_term]}"
          target_string <<  "\t# #{term[:note]}" unless term[:note].empty?
          printf("  %-#{max_str_size+10}s %s\n", term[:source_term], target_string)
        end
      else
        "glossary <#{config['glossary']}> not found"
      end

    rescue Logaling::CommandFailed, Logaling::GlossaryDBNotFound => e
      say e.message
    end

    desc 'list', 'Show glossary list.'
    def list
      @repository.index
      glossaries = @repository.list
      unless glossaries.empty?
        run_pager
        glossaries.each do |glossary|
          printf("  %s\n", glossary)
        end
      else
        "There is no registered glossary."
      end

    rescue Logaling::CommandFailed, Logaling::GlossaryDBNotFound => e
      say e.message
    end

    private
    def glossary
      if @glossary
        @glossary
      else
        required_options = {
          "glossary" => "input glossary name '-g <glossary name>'",
          "source-language" => "input source-language code '-S <source-language code>'",
          "target-language" => "input target-language code '-T <target-language code>'"
        }
        config = load_config_and_merge_options(required_options)
        @glossary = Logaling::Glossary.new(config["glossary"], config["source-language"], config["target-language"])
      end
    end

    def error(msg)
      STDERR.puts(msg)
      exit 1
    end

    def load_config_and_merge_options(required={})
      config_list ||= {}
      find_config.each{|type, path| config_list[type] = load_config(path)}
      global_config = config_list["global_config"] ? config_list["global_config"] : {}
      project_config = config_list["project_config"] ? config_list["project_config"] : {}

      config = merge_options(project_config, global_config)
      config = merge_options(options, config)

      required.each do |required_option, message|
        raise(Logaling::CommandFailed, message) unless config[required_option]
      end

      config
    end

    def merge_options(options, secondary_options)
      config ||={}
      config["glossary"] = options["glossary"] ? options["glossary"] : secondary_options["glossary"]
      config["source-language"] = options["source-language"] ? options["source-language"] : secondary_options["source-language"]
      config["target-language"] = options["target-language"] ? options["target-language"] : secondary_options["target-language"]
      config
    end

    def find_config
      config ||= {}
      config["project_config"] = File.join(find_dotfile, 'config')
      config["global_config"] = global_config_path if global_config_path
      config
    rescue Logaling::CommandFailed
      config ||= {}
      config["project_config"] = @repository.config_path if @repository.config_path
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

    def find_dotfile
      dir = Dir.pwd
      searched_path = []
      while(dir) do
        path = File.join(dir, '.logaling')
        if File.exist?(path)
          return path
        else
          if dir != "/"
            searched_path << dir
            dir = File.dirname(dir)
          else
            raise(Logaling::CommandFailed, "Can't found .logaling in #{searched_path}")
          end
        end
      end
    end

    def global_config_path
      path = File.join(LOGALING_HOME, "config")
      File.exist?(path) ? path : nil
    end

    def write_config(config_path, config)
      File.open(config_path, 'w') do |fp|
        fp.puts "--glossary #{config['glossary']}" if config['glossary']
        fp.puts "--source-language #{config['source-language']}" if config['source-language']
        fp.puts "--target-language #{config['target-language']}" if config['target-language']
      end
    end

    # http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
    def run_pager
      return if ::RUBY_PLATFORM =~ /win32/
      return unless STDOUT.tty?

      read, write = IO.pipe

      unless Kernel.fork # Child process
        STDOUT.reopen(write)
        STDERR.reopen(write) if STDERR.tty?
        read.close
        write.close
        return
      end

      # Parent process, become pager
      STDIN.reopen(read)
      read.close
      write.close

      ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

      # wait until we have input before we start the pager
      Kernel.select [STDIN]
      pager = ENV['PAGER'] || 'less'
      exec pager rescue exec "/bin/sh", "-c", pager
    end

    def extract_source_string_and_coloring(term)
      source_string = term[:snipped_source_term].map do |word|
        word.is_a?(Hash) ? word[:keyword].bright : word
      end
      source_string = source_string.join
      source_string
    end

    def printer(source_string, target_string, note=nil,
                glossary_name, max_str_size, i, last)
      case options["output"]
      when "terminal"
        unless note
          format = target_string + "\t" + glossary_name
        else
          format = target_string + "\t# " + note + "\t" + glossary_name
        end
        printf("  %-#{max_str_size+10}s %s\n", source_string, format)
      when "csv"
        items = [source_string, target_string, note,
                 @source_language, @target_language]
        print(CSV.generate {|csv| csv << items})
      when "json"
        puts("[") if i == 0
        puts(",") if i > 0
        record = {
          :source => source_string, :target => target_string, :note => note,
          :source_language => @source_language,
          :target_language => @target_language
        }
        print JSON.pretty_generate(record)
        puts("\n]") if i == last-1
      end
    end
  end
end
