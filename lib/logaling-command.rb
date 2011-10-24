# -*- encoding: utf-8 -*-
#require "logaling-command/version"

require 'psych'
require "yaml"
require "fileutils"

module Logaling
  class CommandFailed < RuntimeError; end

  def exec(action, options)
    options[:path] = glossary_path(options)

    case action
    when "create"
      create(options)
    when "add"
      add(options)
    when "lookup"
      lookup(options)
    else
      puts "command '#{action}' not found."
    end
  rescue CommandFailed => e
    STDERR.puts(e.message)
    exit 1
  end

  def create(options)
    check_options(options)
    if File.exists?(options[:path])
      puts "glossary #{options[:glossary]} is already exists"
    else
      dirname = File::dirname(options[:path])
      FileUtils.mkdir_p(dirname)
      FileUtils.touch(options[:path])
    end
  end

  def add(options)
    check_glossary(options)
    check_options(options, true, true)

    list = translations(options[:path], options[:keyword])
    list.each do |data|
      if data[:translation] == options[:translation]
        # 既に存在するキーワード&訳文
        puts "[#{options[:keyword]}] [#{options[:translation]}] pair is already exist}"
        return
      end
    end

    File.open(options[:path], "a") do |f|
      glossary = [
        options[:keyword] => {
        :translation => options[:translation],
        :note => options[:note],
      }]
      f.puts(glossary.to_yaml.gsub("---\n", ""))
    end
  end

  def lookup(options)
    check_glossary(options)
    check_options(options, true)

    list = translations(options[:path], options[:keyword])
    if list.empty?
      puts "keyword '#{options[:keyword]}' not found"
      return
    end

    puts "keyword: #{options[:keyword]}\n"
    list.each do |data|
      puts "  translation: #{data[:translation]}\n"
      puts "    note: #{data[:note]}\n"
    end
  end

  def check_glossary(options)
    unless File.exists?(options[:path])
      raise CommandFailed, "glossary #{options[:glossary]} not found"
    end
  end

  def check_options(options, check_keyword=false, check_translation=false)
    if options[:glossary].empty?
      raise CommandFailed, "input glossary name '-g <glossary name>'"
    end
    if options[:from].empty?
      raise CommandFailed, "input source-language code '-F <source-language code>'"
    end
    if options[:to].empty?
      raise CommandFailed, "input translation-language code '-T <translation-language code>'"
    end

    if check_keyword
      if options[:keyword].empty?
        raise CommandFailed, "input keyword '-k <keyword>'"
      end
    end
    if check_translation
      if options[:translation].empty?
        raise CommandFailed, "input translation '-t <translation>'"
      end
    end
  end

  def glossary_path(options)
    dir, file = File::split(options[:glossary])
    if dir == "."
      fname = [options[:glossary], options[:from], options[:to]].join(".")
      return File.join(LOGALING_HOME, "#{fname}.yml")
    else
      return options[:glossary]
    end
  end

  def translations(path, key)
    yaml = YAML::load_file(path)

    translations = []
    return translations if !yaml

    yaml.each do |arr|
      translations << arr[key] if arr[key]
    end
    return translations
  end

  module_function :exec, :create, :check_options, :glossary_path, :add, :translations, :lookup, :check_glossary
end
