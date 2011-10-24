#require "logaling-command/version"
# -*- encoding: utf-8 -*-

require 'psych'
require "yaml"
require "fileutils"

module Logaling
  def exec(action, options)
    options[:path] = glossary_path(options)

    case action
    when "create"
      create(options)
    when "add"
      add(options)
    else
      puts "command '#{action}' not found."
    end
  end

  def create(options)
    return if !check_options(options)
    if File.exists?(options[:path])
      puts "glossary #{options[:glossary]} is already exists"
    else
      dirname = File::dirname(options[:path])
      FileUtils.mkdir_p(dirname)
      FileUtils.touch(options[:path])
    end
  end

  def add(options)
    unless File.exists?(options[:path])
      puts "glossary #{options[:glossary]} not found"
      return
    end
    return if !check_options(options, true)

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

  def check_options(options, check_keyword=false)
    if options[:glossary].empty?
      puts "input glossary name '-g <glossary name>'"
      return false
    end
    if options[:from].empty?
      puts "input source-language code '-F <source-language code>'"
      return false
    end
    if options[:to].empty?
      puts "input translation-language code '-T <translation-language code>'"
      return false
    end

    if check_keyword
      if options[:keyword].empty?
        puts "input keyword '-k <keyword>'"
        return false
      end
      if options[:translation].empty?
        puts "input translation '-t <translation>'"
        return false
      end
    end

    return true
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

  module_function :exec, :create, :check_options, :glossary_path, :add, :translations
end
