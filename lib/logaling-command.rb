#require "logaling-command/version"
# -*- encoding: utf-8 -*-

require "yaml"
require "fileutils"

module Logaling
  def exec(action, options)
    fname = [options[:glossary], options[:from], options[:to]].join(".")
    options[:path] = File.join(LOGALING_HOME, "#{fname}.yml")

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
      Dir::mkdir(LOGALING_HOME) unless FileTest::directory?(LOGALING_HOME)
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

  module_function :exec, :create, :check_options
end
