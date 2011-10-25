# -*- encoding: utf-8 -*-
#require "logaling-command/version"

require 'psych'
require "yaml"
require "fileutils"

module Logaling
  module Command
    class CommandFailed < RuntimeError; end

    class Glossary
      def self.build_path(glossary, from, to)
        dir, file = File::split(glossary)
        if dir == "."
          fname = [glossary, from, to].join(".")
          return File.join(LOGALING_HOME, "#{fname}.yml")
        else
          return glossary
        end
      end

      def initialize(glossary, from, to)
        if glossary.empty?
          raise CommandFailed, "input glossary name '-g <glossary name>'"
        end
        if from.empty?
          raise CommandFailed, "input source-language code '-F <source-language code>'"
        end
        if to.empty?
          raise CommandFailed, "input translation-language code '-T <translation-language code>'"
        end

        @path = Glossary.build_path(glossary, from, to)
      end

      def create
        check_glossary_unexists

        dirname = File::dirname(@path)
        FileUtils.mkdir_p(dirname)
        FileUtils.touch(@path)
      end

      def add(keyword, translation, note)
        check_glossary_exists
        check_keyword(keyword)
        check_translation(translation)

        list = translations(keyword)
        list.each do |data|
          if data[:translation] == translation
            # 既に存在するキーワード&訳文
            puts "[#{keyword}] [#{translation}] pair is already exist}"
            return
          end
        end

        File.open(@path, "a") do |f|
          glossary = [ keyword => { translation: translation, note: note } ]
          f.puts(glossary.to_yaml.gsub("---\n", ""))
        end
      end

      def delete(keyword, translation)
        check_glossary_exists
        check_keyword(keyword)
        check_translation(translation)

        glossary = YAML::load_file(@path)
        target_index = glossary.find_index do |term|
          term[keyword] && term[keyword][:translation] == translation
        end
        if target_index
          glossary.delete_at(target_index)
          File.open(@path, "w") do |f|
            f.puts glossary.to_yaml
          end
        else
          puts "keyword:#{keyword} translation:#{translation} not found in glossary #{@path}"
        end
      end

      def lookup(keyword)
        check_glossary_exists
        check_keyword(keyword)

        list = translations(keyword)
        if list.empty?
          puts "keyword '#{keyword}' not found"
          return
        end

        puts "keyword: #{keyword}\n"
        list.each do |data|
          puts "  translation: #{data[:translation]}\n"
          puts "    note: #{data[:note]}\n"
        end
      end

      private
      def check_glossary_unexists
        if File.exists?(@path)
          raise CommandFailed, "glossary #{@path} is already exists"
        end
      end

      def check_glossary_exists
        unless File.exists?(@path)
          raise CommandFailed, "glossary #{@path} not found"
        end
      end

      def check_keyword(keyword)
        if keyword.empty?
          raise CommandFailed, "input keyword '-k <keyword>'"
        end
      end

      def check_translation(translation)
        if translation.empty?
          raise CommandFailed, "input translation '-t <translation>'"
        end
      end

      def translations(keyword)
        yaml = YAML::load_file(@path)

        translations = []
        return translations if !yaml

        yaml.each do |arr|
          translations << arr[keyword] if arr[keyword]
        end
        return translations
      end
    end
  end
end
