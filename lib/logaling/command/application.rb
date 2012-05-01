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
require 'pathname'
require "logaling/repository"
require "logaling/glossary"
require "logaling/config"

module Logaling::Command
  LOGALING_CONFIG = '.logaling'

  class Application < Thor

    def initialize(*args)
      super
      @logaling_home = options["logaling-home"] ? options["logaling-home"] : LOGALING_HOME
      @repository = Logaling::Repository.new(@logaling_home)
      @config = Logaling::Config.load(@repository.config_path)

      @dotfile_path = options["logaling-config"] ? options["logaling-config"] : find_dotfile
      @project_config_path = File.join(@dotfile_path, 'config')
      @config.load(@project_config_path)
    rescue Logaling::CommandFailed # can't find .logaling
      @project_config_path = nil
    ensure
      @config.merge!(options)
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
    class_option "logaling-config", type: :string, aliases: "-c"

    desc 'new [PROJECT NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE(optional)]', 'Create .logaling'
    method_option "no-register", type: :boolean, default: false
    def new(project_name, source_language, target_language=nil)
      unless File.exist?(logaling_config_path)
        FileUtils.mkdir_p(File.join(logaling_config_path, "glossary"))

        config = Logaling::Config.new("glossary" => project_name, "source-language" => source_language)
        config.merge!("target-language" => target_language) if target_language
        config.save(File.join(logaling_config_path, "config"))

        unless options["no-register"]
          @dotfile_path = options["logaling-config"] ? options["logaling-config"] : find_dotfile
          @project_config_path = File.join(@dotfile_path, 'config')
          @config.load(@project_config_path)
          register_and_index
        end
        say "Successfully created #{logaling_config_path}"
      else
        say "#{logaling_config_path} already exists."
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
        @repository.index
      end
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::ExternalGlossaryNotFound
      say "'#{external_glossary}' can't find in import list."
      say "Try 'loga import --list' and confirm import list."
    end

    desc 'register', 'Register .logaling'
    def register
      raise Logaling::CommandFailed, "Can't use '-g <glossary>' option." if options["glossary"]
      @config.check_required_option("glossary" => "Do 'loga register' at project directory.")
      raise Logaling::CommandFailed, "Try 'loga new' first." unless File.exist?(@dotfile_path)

      register_and_index
      say "#{@config.glossary} is now registered to logaling."
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::GlossaryAlreadyRegistered => e
      say "#{@config.glossary} is already registered."
    end

    desc 'unregister', 'Unregister .logaling'
    def unregister
      raise Logaling::CommandFailed, "Can't use '-g <glossary>' option." if options["glossary"]
      @config.check_required_option("glossary" => "Do 'loga unregister' at project directory.")

      @repository.unregister(@config.glossary)
      @repository.index
      say "#{@config.glossary} is now unregistered."
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "#{@config.glossary} is not yet registered."
    end

   desc 'config [KEY] [VALUE] [--global(optional)]', 'Set config.'
   method_option "global", type: :boolean, default: false
   def config(key, value)
     if options["global"]
       unless File.exist?(@logaling_home)
         FileUtils.mkdir_p(@logaling_home) rescue raise Logaling::CommandFailed, "Input existing directory as logaling-home."
       end
       config_path = File.join(@logaling_home, "config")
     else
       raise Logaling::CommandFailed, "Can't found .logaling" unless @project_config_path
       config_path = @project_config_path
     end
     config = Logaling::Config.load(config_path)
     config.add(key, value)
     config.save(config_path)
     say "Successfully set config."
   rescue Logaling::CommandFailed => e
     say e.message
   end

    desc 'add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]', 'Add term to glossary.'
    def add(source_term, target_term, note='')
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      @config.check_required_option(required_options)
      check_logaling_home_exists
      @repository.index

      if @repository.bilingual_pair_exists?(source_term, target_term, @config.glossary)
        raise Logaling::TermError, "term '#{source_term}: #{target_term}' already exists in '#{@config.glossary}'"
      end

      glossary.add(source_term, target_term, note)
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    end

    desc 'delete [SOURCE TERM] [TARGET TERM(optional)] [--force(optional)]', 'Delete term.'
    method_option "force", type: :boolean, default: false
    def delete(source_term, target_term=nil)
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      @config.check_required_option(required_options)
      check_logaling_home_exists

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
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      @config.check_required_option(required_options)
      check_logaling_home_exists
      @repository.index

      if @repository.bilingual_pair_exists_and_has_same_note?(source_term, new_target_term, note, @config.glossary)
        raise Logaling::TermError, "term '#{source_term}: #{new_target_term}' already exists in '#{@config.glossary}'"
      end

      glossary.update(source_term, target_term, new_target_term, note)
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    end

    desc 'lookup [TERM]', 'Lookup terms.'
    method_option "output", type: :string, default: "terminal"
    method_option "no-pager", type: :boolean, default: false
    method_option "no-color", type: :boolean, default: false
    method_option "dictionary", type: :boolean, default: false, aliases: "--dict"
    def lookup(source_term)
      check_logaling_home_exists
      @repository.index
      terms = @repository.lookup(source_term, glossary, options["dictionary"])
      unless terms.empty?
        max_str_size = terms.map{|term| term[:source_term].size}.sort.last
        run_pager
        terms.each_with_index do |term, i|
          source_string = extract_keyword_and_coloring(term[:snipped_source_term], term[:source_term])
          target_string = extract_keyword_and_coloring(term[:snipped_target_term], term[:target_term])
          note = term[:note].to_s unless term[:note].empty?
          glossary_name = ""
          if @repository.glossary_counts > 1
            glossary_name = term[:glossary_name]
            if term[:glossary_name] == @config.glossary
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
    method_option "no-pager", type: :boolean, default: false
    def show
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      @config.check_required_option(required_options)
      check_logaling_home_exists
      @repository.index
      terms = @repository.show_glossary(glossary)
      unless terms.empty?
        run_pager
        max_str_size = terms.map{|term| term[:source_term].size}.sort.last
        terms.each do |term|
          target_string = "#{term[:target_term]}"
          target_string <<  "\t# #{term[:note]}" unless term[:note].empty?
          printf("  %-#{max_str_size+10}s %s\n", term[:source_term], target_string)
        end
      else
        "glossary <#{@config.glossary}> not found"
      end

    rescue Logaling::CommandFailed, Logaling::GlossaryDBNotFound => e
      say e.message
    end

    desc 'list', 'Show glossary list.'
    method_option "no-pager", type: :boolean, default: false
    def list
      check_logaling_home_exists
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
    def windows?
      RUBY_PLATFORM =~ /win32|mingw32/i
    end

    def glossary
      @glossary ||= Logaling::Glossary.new(@config.glossary, @config.source_language, @config.target_language, @logaling_home)
    end

    def error(msg)
      STDERR.puts(msg)
      exit 1
    end

    def find_dotfile
      dir = Dir.pwd
      searched_path = []
      loop do
        path = File.join(dir, '.logaling')
        if File.exist?(path)
          return path
        else
          unless Pathname.new(dir).root?
            searched_path << dir
            dir = File.dirname(dir)
          else
            raise(Logaling::CommandFailed, "Can't found .logaling in #{searched_path}")
          end
        end
      end
    end

    def logaling_config_path
      if options["logaling-config"]
        options["logaling-config"]
      else
        File.join(Dir.pwd, LOGALING_CONFIG)
      end
    end

    # http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
    def run_pager
      return if options["no-pager"]
      return if windows?
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

    def extract_keyword_and_coloring(snipped_term, term)
      return term if snipped_term.empty? || options["no-color"]
      display_string = snipped_term.map do |word|
        word.is_a?(Hash) ? word[:keyword].bright : word
      end
      display_string = display_string.join
      display_string
    end

    def check_logaling_home_exists
      unless File.exist?(@logaling_home)
        raise Logaling::CommandFailed, "Input existing directory as logaling-home."
      end
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
                 @config.source_language, @config.target_language]
        print(CSV.generate {|csv| csv << items})
      when "json"
        puts("[") if i == 0
        puts(",") if i > 0
        record = {
          :source => source_string, :target => target_string, :note => note,
          :source_language => @config.source_language,
          :target_language => @config.target_language
        }
        print JSON.pretty_generate(record)
        puts("\n]") if i == last-1
      end
    end

    def register_and_index
      @repository.register(@dotfile_path, @config.glossary)
      @repository.index
    end
  end
end
