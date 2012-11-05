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
require "logaling/project"
require "logaling/glossary"
require "logaling/glossary_source"
require "logaling/config"

module Logaling::Command
  LOGALING_CONFIG = '.logaling'

  class Application < Thor

    def initialize(*args)
      super
      @logaling_home = options["logaling-home"] ? options["logaling-home"] : LOGALING_HOME
      @repository = Logaling::Repository.new(@logaling_home)
      @config = Logaling::Config.load(@repository.config_path)

      @dotfile_path = options["logaling-config"] ? options["logaling-config"] : Logaling::Project.find_dotfile
      @project_config_path = File.join(@dotfile_path, 'config')
      @config.load(@project_config_path)
    rescue Logaling::ProjectNotFound => e
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
        '-I' => :index,
        '-L' => :list,
        '-s' => :show,
        '-v' => :version,
        '-c' => :config,
        '-C' => :copy

    class_option "glossary",        type: :string, aliases: "-g"
    class_option "source-language", type: :string, aliases: "-S"
    class_option "target-language", type: :string, aliases: "-T"
    class_option "logaling-home",   type: :string, aliases: "-h"
    class_option "logaling-config", type: :string, aliases: "-c"

    desc 'new [PROJECT NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE(optional)]', 'Create .logaling'
    method_option "no-register", type: :boolean, default: false
    method_option "personal", type: :boolean, default: false
    def new(project_name, source_language, target_language=nil)
      unless options['personal']
        unless File.exist?(logaling_config_path)
          FileUtils.mkdir_p(File.join(logaling_config_path, "glossary"))

          config = Logaling::Config.new("glossary" => project_name, "source-language" => source_language)
          config.merge!("target-language" => target_language) if target_language
          config.save(File.join(logaling_config_path, "config"))

          unless options["no-register"]
            @dotfile_path = options["logaling-config"] || Logaling::Project.find_dotfile
            @project_config_path = File.join(@dotfile_path, 'config')
            @config.load(@project_config_path)
            @repository.register(@dotfile_path, @config.glossary)
          end
          say "Successfully created #{logaling_config_path}"
        else
          say "#{logaling_config_path} already exists."
        end
      else
        raise Logaling::CommandFailed, "[TARGET-LANGUAGE] is required when you use '--personal'" unless target_language
        personal_project = @repository.create_personal_project(project_name, source_language, target_language)
        say "Successfully created #{personal_project.path}"
      end
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::GlossaryAlreadyRegistered => e
      say e.message
    end

    desc 'import', 'Import external glossary'
    method_option "list", type: :boolean, default: false
    def import(external_glossary=nil, *args)
      require "logaling/external_glossary"
      Logaling::ExternalGlossary.load
      if options["list"]
        Logaling::ExternalGlossary.list.each {|glossary_source| say "#{glossary_source.name.bright} : #{glossary_source.description} (#{glossary_source.url})" }
      else
        case external_glossary
        when 'tmx'
          check_import_parameter(args)
          url = args[1]
          if url && !URI.parse(url).host
            url = File.expand_path(url)
          end
          glossary = Logaling::Glossary.new(args[0], args[2], args[3])
          @repository.import_tmx(Logaling::ExternalGlossary.get(external_glossary), glossary, url)
        else
          @repository.import(Logaling::ExternalGlossary.get(external_glossary))
        end
      end
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::ExternalGlossaryNotFound
      say "'#{external_glossary}' can't find in import list."
      say "Try 'loga import --list' and confirm import list."
    rescue Logaling::GlossaryNotFound => e
      say e.message
    end

    desc 'register', 'Register .logaling'
    def register
      raise Logaling::CommandFailed, "Can't use '-g <glossary>' option." if options["glossary"]
      @config.check_required_option("glossary" => "Do 'loga register' at project directory.")
      raise Logaling::CommandFailed, "Try 'loga new' first." unless File.exist?(@dotfile_path)

      @repository.register(@dotfile_path, @config.glossary)
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

      project = @repository.find_project(@config.glossary)
      @repository.unregister(project)
      say "#{@config.glossary} is now unregistered."
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::ProjectNotFound => e
      say "#{@config.glossary} is not yet registered."
    end

    desc 'index', 'Index glossaries'
    def index
      check_logaling_home_exists

      @repository.index
      say 'Complete index.'
    rescue Logaling::CommandFailed => e
      say e.message
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
      project = @repository.find_project(@config.glossary)
      raise Logaling::ProjectNotFound unless project
      raise Logaling::ProjectNotFound if project.imported?
      glossary = project.glossary(@config.source_language, @config.target_language)

      glossary.add(source_term, target_term, note)
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::TermError => e
      say "term '#{source_term}: #{target_term}' already exists in '#{@config.glossary}'"
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    rescue Logaling::ProjectNotFound
      say "glossary <#{@config.glossary}> not found."
      say "Try 'loga list' and confirm glossary name."
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
      project = @repository.find_project(@config.glossary)
      raise Logaling::ProjectNotFound unless project
      glossary = project.glossary(@config.source_language, @config.target_language)

      if target_term
        glossary.delete(source_term, target_term)
      else
        glossary.delete_all(source_term, options["force"])
      end
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    rescue Logaling::ProjectNotFound
      say "glossary <#{@config.glossary}> not found."
      say "Try 'loga list' and confirm glossary name."
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
      project = @repository.find_project(@config.glossary)
      raise Logaling::ProjectNotFound unless project
      glossary = project.glossary(@config.source_language, @config.target_language)

      glossary.update(source_term, target_term, new_target_term, note)
    rescue Logaling::CommandFailed => e
      say e.message
    rescue Logaling::TermError => e
      say "term '#{source_term}: #{new_target_term}' already exists in '#{@config.glossary}'"
    rescue Logaling::GlossaryNotFound => e
      say "Try 'loga new or register' first."
    rescue Logaling::ProjectNotFound
      say "glossary <#{@config.glossary}> not found."
      say "Try 'loga list' and confirm glossary name."
    end

    desc 'lookup [TERM]', 'Lookup terms.'
    method_option "output", type: :string, default: "terminal"
    method_option "no-pager", type: :boolean, default: false
    method_option "no-color", type: :boolean, default: false
    method_option "dictionary", type: :boolean, default: false, aliases: "--dict"
    method_option "fixed", type: :boolean, default: false
    def lookup(source_term)
      check_logaling_home_exists
      if @config.glossary
        project = @repository.find_project(@config.glossary)
        raise Logaling::ProjectNotFound unless project
        glossary = project.glossary(@config.source_language, @config.target_language)
      else
        glossary = nil
      end
      terms = @repository.lookup(source_term, glossary, options)
      unless terms.empty?
        run_pager
        terms.each_with_index do |term, i|
          case options["output"]
          when "terminal"
            term_renderer = Logaling::Command::Renderers::TermDefaultRenderer.new(term, @repository, @config, options)
            term_renderer.set_max_source_term_width(terms)
            term_renderer.render($stdout)
          when "csv"
            term_renderer = Logaling::Command::Renderers::TermCsvRenderer.new(term, @repository, @config, options)
            term_renderer.render($stdout)
          when "json"
            term_renderer = Logaling::Command::Renderers::TermJsonRenderer.new(term, @repository, @config, options)
            term_renderer.index = i
            term_renderer.last_index = terms.length
            term_renderer.render($stdout)
          end
        end
      else
        "source-term <#{source_term}> not found"
      end
    rescue Logaling::ProjectNotFound
      say "glossary <#{@config.glossary}> not found."
      say "Try 'loga list' and confirm glossary name."
    rescue Logaling::CommandFailed, Logaling::TermError => e
      say e.message
    end

    desc 'version', 'Show version.'
    def version
      say "logaling-command version #{Logaling::Command::VERSION}"
    end

    desc 'show', 'Show terms in glossary.'
    method_option "no-pager", type: :boolean, default: false
    method_option "annotation", type: :string, aliases: "-A"
    def show
      required_options = {
        "glossary" => "input glossary name '-g <glossary name>'",
        "source-language" => "input source-language code '-S <source-language code>'",
        "target-language" => "input target-language code '-T <target-language code>'"
      }
      @config.check_required_option(required_options)
      check_logaling_home_exists
      glossary = @repository.find_glossary(@config.glossary, @config.source_language, @config.target_language)
      raise Logaling::GlossaryNotFound unless glossary
      terms = glossary.terms(options["annotation"])
      unless terms.empty?
        run_pager
        terms.each do |term|
          term_renderer = Logaling::Command::Renderers::TermDefaultRenderer.new(term, @repository, @config, options)
          term_renderer.set_max_source_term_width(terms)
          term_renderer.hide_glossary_name
          term_renderer.render($stdout)
        end
      else
        "glossary <#{@config.glossary}> not found"
      end
    rescue Logaling::CommandFailed, Logaling::GlossaryDBNotFound => e
      say e.message
    rescue Logaling::GlossaryNotFound
      say "glossary <#{@config.glossary}> not found."
      say "Try 'loga list' and confirm glossary name."
    end

    desc 'list', 'Show glossary list.'
    method_option "no-pager", type: :boolean, default: false
    def list
      check_logaling_home_exists
      @repository.index
      projects = @repository.projects
      unless projects.empty?
        run_pager
        # 用語集の一覧といいつつプロジェクトの一覧を出していて、
        # かつ個人用のプロジェクトと .logaling によるプロジェクトで
        # プロジェクトとして表現しているスコープが異なっているために、
        # 重複した名前のプロジェクトが表示されるケースが存在する
        #TODO 表示する情報の単位を整理後に見直す
        projects.map(&:name).uniq.each do |project_name|
          printf("  %s\n", project_name)
        end
      else
        "There is no registered glossary."
      end
    rescue Logaling::CommandFailed, Logaling::GlossaryDBNotFound => e
      say e.message
    end

    desc 'copy [GLOSSARY NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE] [NEW GLOSSARY NAME] [NEW SOURCE LANGUAGE] [NEW TARGET LANGUAGE]', 'Copy personal glossary'
    def copy(project_name, source_language, target_language, new_project_name, new_source_language, new_target_language)
      check_logaling_home_exists

      src_glossary = @repository.find_glossary(project_name, source_language, target_language)
      unless src_glossary
        raise Logaling::GlossaryNotFound, "Can't found #{project_name}.#{source_language}.#{target_language}"
      end

      dest_project = @repository.create_personal_project(new_project_name, new_source_language, new_target_language)
      dest_glossary = dest_project.glossary(new_source_language, new_target_language)

      dest_glossary.merge!(src_glossary)
    rescue Logaling::CommandFailed, Logaling::GlossaryAlreadyRegistered, Logaling::GlossaryNotFound => e
      say e.message
    end

    private
    def error(msg)
      STDERR.puts(msg)
      exit 1
    end

    def logaling_config_path
      if options["logaling-config"]
        options["logaling-config"]
      else
        File.join(Dir.pwd, LOGALING_CONFIG)
      end
    end

    def run_pager
      Pager.run unless options["no-pager"]
    end

    def check_logaling_home_exists
      unless File.exist?(@logaling_home)
        raise Logaling::CommandFailed, "Input existing directory as logaling-home."
      end
    end

    def check_import_parameter(args)
      unless args[0] && args[1]
        raise Logaling::CommandFailed, "Do 'loga import tmx <glossary name> <url or path>'"
      end
    end
  end
end
