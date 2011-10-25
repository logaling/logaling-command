# -*- encoding: utf-8 -*-

require 'psych'
require "yaml"
require "fileutils"

require "logaling-command/version"
require "logaling-command/glossary"

module Logaling
  module Command
    def exec(action, options)
      glossary = Glossary.new(options[:glossary], options[:from], options[:to])

      case action
      when "create"
        glossary.create
      when "add"
        glossary.add(options[:keyword], options[:translation], options[:note])
      when "lookup"
        glossary.lookup(options[:keyword])
      else
        puts "command '#{action}' not found."
      end
    rescue CommandFailed => e
      STDERR.puts(e.message)
      exit 1
    end

    module_function :exec
  end
end
