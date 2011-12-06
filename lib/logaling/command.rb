# -*- coding: utf-8 -*-

require 'thor'
require "logaling/glossary"

class Logaling::Command < Thor
  VERSION = "0.0.6"
  LOGALING_CONFIG = '.logaling'

  map '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup,
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

  desc 'register', 'Register .logaling'
  def register
    logaling_path = find_dotfile
    FileUtils.mkdir_p(logaling_projects_path) unless File.exist?(logaling_projects_path)

    config = load_config
    symlink_path = File.join(logaling_projects_path, config["glossary"])
    unless File.exists?(symlink_path)
      FileUtils.ln_s(logaling_path, symlink_path)
      say "#{config['glossary']} is now registered to logaling."
    else
      say "#{config['glossary']} is already registered."
    end
  rescue Logaling::CommandFailed => e
    say e.message
    say "Try 'loga new' first."
  end

  desc 'unregister', 'Unregister .logaling'
  def unregister
    logaling_path = find_dotfile
    config = load_config
    symlink_path = File.join(logaling_projects_path, config["glossary"])
    if File.exists?(symlink_path)
      FileUtils.remove_entry_secure(symlink_path, true)
      say "#{config['glossary']} is now unregistered."
    else
      say "#{config['glossary']} is not yet registered."
    end
  rescue Logaling::CommandFailed => e
    say e.message
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
    glossary.index
    terms = glossary.lookup(source_term)

    unless terms.empty?
      terms.each do |term|
        str_term = "#{term[:source_term]} : #{term[:target_term]}"
        str_term << " # #{term[:note]}" unless term[:note].empty?
        puts str_term
        puts "(#{term[:name]})" if registered_project_counts > 1
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
  def glossary
    config = load_config

    glossary = options["glossary"] || config["glossary"]
    raise(Logaling::CommandFailed, "input glossary name '-g <glossary name>'") unless glossary

    source_language = options["source-language"] || config["source-language"]
    raise(Logaling::CommandFailed, "input source-language code '-S <source-language code>'") unless source_language

    target_language = options["target-language"] || config["target-language"]
    raise(Logaling::CommandFailed, "input target-language code '-T <target-language code>'") unless target_language

    Logaling::Glossary.new(glossary, source_language, target_language)
  end

  def logaling_projects_path
    File.join(LOGALING_HOME, "projects")
  end

  def registered_project_counts
    Dir.entries(logaling_projects_path).reject{|dir| dir.sub(/[\.]+/, '').empty?}.size
  end

  def error(msg)
    STDERR.puts(msg)
    exit 1
  end

  def load_config
    config ||= {}
    if path = find_dotfile
      File.readlines(File.join(path, 'config')).map{|l| l.chomp.split " "}.each do |option|
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
