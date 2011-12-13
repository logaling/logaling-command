# -*- coding: utf-8 -*-

require 'thor'
require 'rainbow'
require "logaling/repository"
require "logaling/glossary"
require "logaling/external_glossary"

class Logaling::Command < Thor
  VERSION = "0.0.9"
  LOGALING_CONFIG = '.logaling'

  map '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup,
      '-i' => :import,
      '-n' => :new,
      '-r' => :register,
      '-U' => :unregister,
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
      File.open(File.join(LOGALING_CONFIG, "config"), 'w') do |config|
        config.puts "--glossary #{project_name}"
        config.puts "--source-language #{source_language}"
        config.puts "--target-language #{target_language}" if target_language
      end
      register unless options["no-register"]
      say "Successfully created #{LOGALING_CONFIG}"
    else
      say "#{LOGALING_CONFIG} already exists."
    end
  end

  desc 'import', 'Import external glossary'
  method_option "list", type: :boolean, default: false
  def import(external_glossary=nil)
    Logaling::ExternalGlossary.load
    if options["list"]
      Logaling::ExternalGlossary.list.each {|glossary| say "#{glossary.name.bright} : #{glossary.description}" }
    else
      repository.import(Logaling::ExternalGlossary.get(external_glossary))
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

    repository.register(logaling_path, config["glossary"])
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

    repository.unregister(config["glossary"])
    say "#{config['glossary']} is now unregistered."
  rescue Logaling::CommandFailed => e
    say e.message
  rescue Logaling::GlossaryNotFound => e
    say "#{config['glossary']} is not yet registered."
  end

  desc 'add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]', 'Add term to glossary.'
  def add(source_term, target_term, note='')
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

  desc 'update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]', 'Update term.'
  def update(source_term, target_term, new_target_term, note='')
    glossary.update(source_term, target_term, new_target_term, note)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    say e.message
  rescue Logaling::GlossaryNotFound => e
    say "Try 'loga new or register' first."
  end

  desc 'lookup [TERM]', 'Lookup terms.'
  def lookup(source_term)
    config = load_config_and_merge_options
    repository.index
    terms = repository.lookup(source_term, config["source_language"], config["target_language"], config["glossary"])

    unless terms.empty?
      terms.each do |term|
        str_term = "#{term[:source_term].bright}\t\t: #{term[:target_term]}"
        str_term << "\t# #{term[:note]}" unless term[:note].empty?
        if repository.registered_project_counts > 1
          color = (term[:name] == config["glossary"]) ? :green : :cyan
          str_term << "\t(#{term[:name]})".color(color)
        end
        puts "  #{str_term}"
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

  private
  def repository
    @repository ||= Logaling::Repository.new(LOGALING_HOME)
  end

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
    config = load_config
    config["glossary"] = options["glossary"] ? options["glossary"] : config["glossary"]
    config["source-language"] = options["source-language"] ? options["source-language"] : config["source-language"]
    config["target-language"] = options["target-language"] ? options["target-language"] : config["target-language"]

    required.each do |required_option, message|
      raise(Logaling::CommandFailed, message) unless config[required_option]
    end

    config
  end

  def find_config
    File.join(find_dotfile, 'config')
  rescue Logaling::CommandFailed
    repository.config_path
  end

  def load_config
    config ||= {}
    if config_path = find_config
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
end
