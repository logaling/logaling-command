# -*- encoding: utf-8 -*-

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

  desc 'create', 'Create glossary.'
  method_option :glossary, type: :string, required: true
  method_option :from, type: :string, required: true
  method_option :to, type: :string, required: true
  def create
    glossary.create
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'add', 'Add term to glossary.'
  method_option :glossary, type: :string, required: true
  method_option :from, type: :string, required: true
  method_option :to, type: :string, required: true
  method_option :keyword, type: :string, required: true
  method_option :translation, type: :string, required: true
  method_option :note, type: :string
  def add
    glossary.add(options[:keyword], options[:translation], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'delete', 'Delete term.'
  method_option :glossary, type: :string, required: true
  method_option :from, type: :string, required: true
  method_option :to, type: :string, required: true
  method_option :keyword, type: :string, required: true
  method_option :translation, type: :string, required: true
  def delete
    glossary.delete(options[:keyword], options[:translation])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'update', 'Update term.'
  method_option :glossary, type: :string, required: true
  method_option :from, type: :string, required: true
  method_option :to, type: :string, required: true
  method_option :keyword, type: :string, required: true
  method_option :translation, type: :string, required: true
  method_option :new_translation, type: :string, required: true
  method_option :note, type: :string, required: true
  def update
    glossary.update(options[:keyword], options[:translation], options[:new_translation], options[:note])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'lookup', 'Lookup terms.'
  method_option :glossary, type: :string, required: true
  method_option :from, type: :string, required: true
  method_option :to, type: :string, required: true
  method_option :keyword, type: :string, required: true
  def lookup
    glossary.lookup(options[:keyword])
  rescue Logaling::CommandFailed => e
    error(e.message)
  end

  desc 'index', 'Index glossaries to groonga DB.'
  def index
    glossarydb = Logaling::GlossaryDB.new
    glossarydb.open(LOGALING_DB_HOME, "utf8") do |db|
      db.load_glossaries(LOGALING_HOME)
    end
  end

  private
  def glossary
    Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
  end

  def error(msg)
    STDERR.puts(msg)
    exit 1
  end
end
