# -*- encoding: utf-8 -*-

require 'thor'
require "logaling/glossary"
require "logaling/glossary_db"

DOT_OPTIONS = Hash.new

class Logaling::Command < Thor
  VERSION = "0.0.1"

  map '-c' => :create,
      '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup


  desc 'create', 'Create glossary.'
  method_option :glossary, type: :string, aliases: "-g"
  method_option :from, type: :string, aliases: "-F"
  method_option :to, type: :string, aliases: "-T"
  def create
    load_config
    glossary.create
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'add', 'Add term to glossary.'
  method_option :glossary, type: :string, aliases: "-g"
  method_option :from, type: :string, aliases: "-F"
  method_option :to, type: :string, aliases: "-T"
  method_option :keyword, type: :string, required: true, aliases: "-k"
  method_option :translation, type: :string, required: true, aliases: "-t"
  method_option :note, type: :string, aliases: "-n"
  def add
    load_config
    glossary.add(options[:keyword], options[:translation], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'delete', 'Delete term.'
  method_option :glossary, type: :string, aliases: "-g"
  method_option :from, type: :string, aliases: "-F"
  method_option :to, type: :string, aliases: "-T"
  method_option :keyword, type: :string, required: true, aliases: "-k"
  method_option :translation, type: :string, required: true, aliases: "-t"
  def delete
    load_config
    glossary.delete(options[:keyword], options[:translation])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'update', 'Update term.'
  method_option :glossary, type: :string, aliases: "-g"
  method_option :from, type: :string, aliases: "-F"
  method_option :to, type: :string, aliases: "-T"
  method_option :keyword, type: :string, required: true, aliases: "-k"
  method_option :translation, type: :string, required: true, aliases: "-t"
  method_option :new_translation, type: :string, required: true, aliases: "-nt"
  method_option :note, type: :string, required: true, aliases: "-n"
  def update
    load_config
    glossary.update(options[:keyword], options[:translation], options[:new_translation], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'lookup', 'Lookup terms.'
  method_option :glossary, type: :string, aliases: "-g"
  method_option :from, type: :string, aliases: "-F"
  method_option :to, type: :string, aliases: "-T"
  method_option :keyword, type: :string, required: true, aliases: "-k"
  def lookup
    load_config
    glossary.lookup(options[:keyword], options[:glossary])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'index', 'Index glossaries to groonga DB.'
  def index
    glossarydb = Logaling::GlossaryDB.new
    glossarydb.open(LOGALING_DB_HOME, "utf8") do |db|
      db.recreate_table(LOGALING_DB_HOME)
      db.load_glossaries(LOGALING_HOME)
    end
  end

  private
  def glossary
    glossary = options[:glossary] ? options[:glossary] : DOT_OPTIONS["glossary"]
    from     = options[:from] ? options[:from] : DOT_OPTIONS["from"]
    to       = options[:to] ? options[:to] : DOT_OPTIONS["to"]

    Logaling::Glossary.new(glossary, from, to)
  end

  def error(msg)
    STDERR.puts(msg)
    exit 1
  end

  def load_config
    if File.exists?(".logaling")
      dot_options = File.readlines(".logaling").map {|l| l.chomp.split " "}
      dot_options.each do |option|
        key = option[0].sub(/^[\-]{2}/, "")
        value = option[1]
        DOT_OPTIONS[key] = value
      end
    end
  end
end
