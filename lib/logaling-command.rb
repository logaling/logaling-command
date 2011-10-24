#require "logaling-command/version"
# -*- encoding: utf-8 -*-

require "yaml"
require "fileutils"

module Logaling
  def exec(action, options)
    options[:path] = glossary_path(options)

    case action
    when "create"
      create(options)
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
      Dir::mkdir(dirname) unless FileTest::directory?(dirname)
      FileUtils.touch(options[:path])
    end
  end

  def check_options(options)
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

  module_function :exec, :create, :check_options, :glossary_path
end
