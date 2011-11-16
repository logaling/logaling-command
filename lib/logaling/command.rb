# -*- coding: utf-8 -*-

require 'thor'
require "logaling/glossary"
require "logaling/glossary_db"

class Logaling::Command < Thor
  VERSION = "0.0.2"

  map '-c' => :create,
      '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup

  class_option "glossary",        type: :string, aliases: "-g"
  class_option "source-language", type: :string, aliases: "-S"
  class_option "target-language", type: :string, aliases: "-T"
  class_option "logaling-home",   type: :string, required: false, aliases: "-h"

  desc 'create', 'Create glossary.'
  def create
    load_config
    glossary.create
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'add [source term] [target term] [note]', 'Add term to glossary.'
  def add(source_term, target_term, note='')
    load_config
    glossary.add(source_term, target_term, note)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'delete [source term] [target term]', 'Delete term.'
  def delete(source_term, target_term)
    load_config
    glossary.delete(source_term, target_term)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'update [source term] [target term] [new_target_term], [note]', 'Update term.'
  def update(source_term, target_term, new_target_term, note='')
    load_config
    glossary.update(source_term, target_term, new_target_term, note)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'lookup [source term]', 'Lookup terms.'
  def lookup(source_term)
    load_config
    glossary.lookup(source_term)
  rescue Logaling::CommandFailed, Logaling::TermError => e
    error(e.message)
  end

  desc 'index', 'Index glossaries to groonga DB.'
  def index
    load_config
    home = find_option("logaling-home") || LOGALING_HOME
    db_home = File.join(home, ".logadb")
    glossarydb = Logaling::GlossaryDB.new
    glossarydb.open(db_home, "utf8") do |db|
      db.recreate_table(db_home)
      db.load_glossaries(home)
    end
  end

  private
  def glossary
    glossary = find_option("glossary")
    raise(Logaling::CommandFailed, "input glossary name '-g <glossary name>'") unless glossary

    source_language = find_option("source-language")
    raise(Logaling::CommandFailed, "input source-language code '-S <source-language code>'") unless source_language

    target_language = find_option("target-language")
    raise(Logaling::CommandFailed, "input target-language code '-T <target-language code>'") unless target_language

    logaling_home = find_option("logaling-home")

    Logaling::Glossary.new(glossary, source_language, target_language, logaling_home)
  end

  def error(msg)
    STDERR.puts(msg)
    exit 1
  end

  def find_option(key)
    options[key] || @dot_options[key]
  end

  def load_config
    @dot_options ||= {}
    if path = find_dotfile
      tmp_options = File.readlines(path).map {|l| l.chomp.split " "}
      tmp_options.each do |option|
        key = option[0].sub(/^[\-]{2}/, "")
        value = option[1]
        @dot_options[key] = value
      end
    end
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
