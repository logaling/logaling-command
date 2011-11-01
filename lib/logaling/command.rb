# -*- coding: utf-8 -*-

require 'thor'
require "logaling/glossary"
require "logaling/glossary_db"

class Logaling::Command < Thor
  VERSION = "0.0.1"

  map '-c' => :create,
      '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup

  class_option :glossary, type: :string, aliases: "-g"
  class_option :source_language, type: :string, aliases: "-S"
  class_option :target_language, type: :string, aliases: "-T"
  class_option :logaling_home, type: :string, required: false, aliases: "-h"

  def initialize(*args)
    super
    @dot_options = Hash.new
  end

  desc 'create', 'Create glossary.'
  def create
    load_config
    glossary.create
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'add', 'Add term to glossary.'
  method_option :source_term, type: :string, required: true, aliases: "-s"
  method_option :target_term, type: :string, required: true, aliases: "-t"
  method_option :note, type: :string, aliases: "-n"
  def add
    load_config
    glossary.add(options[:source_term], options[:target_term], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'delete', 'Delete term.'
  method_option :source_term, type: :string, required: true, aliases: "-s"
  method_option :target_term, type: :string, required: true, aliases: "-t"
  def delete
    load_config
    glossary.delete(options[:source_term], options[:target_term])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'update', 'Update term.'
  method_option :source_term, type: :string, required: true, aliases: "-s"
  method_option :target_term, type: :string, required: true, aliases: "-t"
  method_option :new_target_term, type: :string, required: true, aliases: "-nt"
  method_option :note, type: :string, required: true, aliases: "-n"
  def update
    load_config
    glossary.update(options[:source_term], options[:target_term], options[:new_target_term], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'lookup', 'Lookup terms.'
  method_option :source_term, type: :string, required: true, aliases: "-s"
  def lookup
    load_config
    glossary.lookup(options[:source_term])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'index', 'Index glossaries to groonga DB.'
  def index
    load_config
    home = options[:logaling_home] ? options[:logaling_home] :
             @dot_options["logaling_home"] ? @dot_options["logaling_home"] :
               LOGALING_HOME
    db_home = File.join(home, ".logadb")
    glossarydb = Logaling::GlossaryDB.new
    glossarydb.open(db_home, "utf8") do |db|
      db.recreate_table(db_home)
      db.load_glossaries(home)
    end
  end

  private
  def glossary
    glossary =
      options[:glossary] ? options[:glossary] :
        @dot_options["glossary"] ? @dot_options["glossary"] :
          raise(Logaling::CommandFailed, "input glossary name '-g <glossary name>'")
    source_language =
      options[:source_language] ? options[:source_language] :
        @dot_options["source_language"] ? @dot_options["source_language"] :
          raise(Logaling::CommandFailed, "input source-language code '-S <source-language code>'")
    target_language =
      options[:target_language] ? options[:target_language] :
        @dot_options["target_language"] ? @dot_options["target_language"] :
          raise(Logaling::CommandFailed, "input target-language code '-T <target-language code>'")
    logaling_home =
      options[:logaling_home] ? options[:logaling_home] :
        @dot_options["logaling_home"] ? @dot_options["logaling_home"] :
          ""

    Logaling::Glossary.new(glossary, source_language, target_language, logaling_home)
  end

  def error(msg)
    STDERR.puts(msg)
    exit 1
  end

  def load_config
    if File.exists?(".logaling")
      tmp_options = File.readlines(".logaling").map {|l| l.chomp.split " "}
      tmp_options.each do |option|
        key = option[0].sub(/^[\-]{2}/, "")
        value = option[1]
        @dot_options[key] = value
      end
    end
  end
end
