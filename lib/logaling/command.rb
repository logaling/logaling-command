# -*- coding: utf-8 -*-

require 'thor'
require "logaling/glossary"
require "logaling/glossary_db"

class Logaling::Command < Thor
  VERSION = "0.0.2"
  LOGALING_CONFIG = '.logaling'

  map '-c' => :create,
      '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup,
      '-n' => :new,
      '-L' => :link

  class_option "glossary",        type: :string, aliases: "-g"
  class_option "source-language", type: :string, aliases: "-S"
  class_option "target-language", type: :string, aliases: "-T"
  class_option "logaling-home",   type: :string, required: false, aliases: "-h"

  desc 'new [PROJECT NAME] [SOURCE LANGUAGE] [TARGET LANGUAGE(optional)]', 'Create .logaling'
  def new(project_name, source_language, target_language=nil)
    unless File.exist?(LOGALING_CONFIG)
      FileUtils.mkdir_p(LOGALING_CONFIG)
      FileUtils.mkdir_p(File.join(LOGALING_CONFIG, "glossary"))
      File.open(File.join(LOGALING_CONFIG, "config"), 'w') do |config|
        config.puts "--glossary #{project_name}"
        config.puts "--source-language #{source_language}"
        config.puts "--target-language #{target_language}" if target_language
      end
      say "Successfully created #{LOGALING_CONFIG}"
    else
      say "#{LOGALING_CONFIG} is already exists."
    end
  end

  desc 'link', 'Link .logaling'
  def link
    logaling_path = find_dotfile
    if logaling_path
      logaling_projects_path = File.join(LOGALING_HOME, "projects")
      FileUtils.mkdir_p(logaling_projects_path) unless File.exist?(logaling_projects_path)

      config = load_config
      symlink_path = File.join(logaling_projects_path, config["glossary"])
      unless File.exists?(symlink_path)
        FileUtils.ln_s(logaling_path, symlink_path)
        say "Your project is now linked to #{symlink_path}."
      else
        say "#{options["glossary"]} is already linked."
      end
    else
      say "Try 'loga new' first."
    end
  end

  desc 'create', 'Create glossary.'
  def create
    glossary.create
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'add [SOURCE TERM] [TARGET TERM] [NOTE(optional)]', 'Add term to glossary.'
  def add(source_term, target_term, note='')
    glossary.add(source_term, target_term, note)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'delete [SOURCE TERM] [TARGET TERM]', 'Delete term.'
  def delete(source_term, target_term)
    glossary.delete(source_term, target_term)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'update [SOURCE TERM] [TARGET TERM] [NEW TARGET TERM], [NOTE(optional)]', 'Update term.'
  def update(source_term, target_term, new_target_term, note='')
    glossary.update(source_term, target_term, new_target_term, note)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'lookup [TERM]', 'Lookup terms.'
  def lookup(source_term)
    glossary.lookup(source_term)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'index', 'Index glossaries to groonga DB.'
  def index
    projects = Dir.glob(File.join(LOGALING_HOME, "projects", "*"))
    db_home = File.join(LOGALING_HOME, "db")
    glossarydb = Logaling::GlossaryDB.new
    glossarydb.open(db_home, "utf8") do |db|
      db.recreate_table(db_home)
      projects.each do |project|
        db.load_glossaries(File.join(project, "glossary"))
      end
    end
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
    while(dir) do
      path = File.join(dir, '.logaling')
      if File.exist?(path)
        return path
        break
      end
      dir = (dir != "/") ? File.dirname(dir) : nil
    end
  end
end
