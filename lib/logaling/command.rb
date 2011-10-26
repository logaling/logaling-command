# -*- encoding: utf-8 -*-

require 'thor'
require "logaling/glossary"

class Logaling::Command < Thor
  VERSION = "0.0.1"

  map '-c' => :create,
      '-a' => :add,
      '-d' => :delete,
      '-u' => :update,
      '-l' => :lookup

  desc 'create', 'Create glossary.'
  method_options glossary: :string, from: :string, to: :string
  def create
    glossary = Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
    glossary.create
  end

  desc 'add', 'Add term to glossary.'
  method_options glossary: :string, from: :string, to: :string, keyword: :string, translation: :string, note: :string
  def add
    glossary = Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
    glossary.add(options[:keyword], options[:translation], options[:note])
  end

  desc 'delete', 'Delete term.'
  method_options glossary: :string, from: :string, to: :string, keyword: :string, translation: :string
  def delete
    glossary = Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
    glossary.delete(options[:keyword], options[:translation])
  end

  desc 'update', 'Update term.'
  method_options glossary: :string, from: :string, to: :string, keyword: :string, translation: :string, new_translation: :string
  def update
    glossary = Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
    glossary.update(options[:keyword], options[:translation], options[:new_translation], options[:note])
  end

  desc 'lookup', 'Lookup terms.'
  method_options glossary: :string, from: :string, to: :string, keyword: :string
  def lookup
    glossary = Logaling::Glossary.new(options[:glossary], options[:from], options[:to])
    glossary.lookup(options[:keyword])
  end
end
