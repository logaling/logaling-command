# -*- encoding: utf-8 -*-
#require "logaling-command/version"

require 'psych'
require "yaml"
require "fileutils"

module Logaling
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
      @from_language = from
      @to_language = to
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

      if translations(keyword).any?{|data| data[:translation] == translation }
        # key-translation pair that already exist
        puts "[#{keyword}] [#{translation}] pair is already exist}"
        return
      end

      File.open(@path, "a") do |f|
        glossary = [ keyword => { translation: translation, note: note } ]
        f.puts(glossary.to_yaml.gsub("---\n", ""))
      end
    end

    def update(keyword, translation, new_translation, note)
      check_glossary_exists
      check_keyword(keyword)
      check_translation(translation)
      check_newtranslation_note(new_translation, note)

      if translations(keyword).any?{|data| data[:translation] == new_translation }
        # key-new_translation pair that already exist
        puts "[#{keyword}] [#{new_translation}] pair is already exist}"
        return
      end

      glossary = YAML::load_file(@path)
      target_index = glossary.find_index do |term|
        term[keyword] && term[keyword][:translation] == translation
      end
      if target_index
        note = glossary[target_index][keyword][:note] if note == ""
        new_translation = glossary[target_index][keyword][:translation] if new_translation == ""
        glossary[target_index] = { keyword => { translation: new_translation, note: note } }
        File.open(@path, "w") do |f|
          f.puts glossary.to_yaml
        end
      else
        puts "keyword:#{keyword} translation:#{translation} not found in glossary #{@path}"
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

      puts "\nkeyword: #{keyword}\n\n"

      lookup_files.each do |path|
        puts "  [#{path}]"
        list = translations(keyword, path)
        if list.empty?
          puts "  not found\n\n"
        else
          list.each do |data|
            puts "  translation: #{data[:translation]}\n"
            puts "    note: #{data[:note]}\n\n"
          end
        end
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

    def check_newtranslation_note(new_translation, note)
      if new_translation.empty? && note.empty?
        raise CommandFailed, "input new translation '-nt <new translation>' or note '-n <note>'"
      end
    end

    def translations(keyword, path=@path)
      yaml = YAML::load_file(path)

      translations = []
      return translations if !yaml

      yaml.each do |arr|
        translations << arr[keyword] if arr[keyword]
      end
      return translations
    end

    def lookup_files
      file_list = Dir.glob("#{LOGALING_HOME}/*.#{@from_language}.#{@to_language}.yml")
      if glossary_index = file_list.index(@path)
        file_list.delete_at(glossary_index)
        file_list.unshift(@path)
      else
        file_list.unshift(@path)
      end
      return file_list
    end
  end
end
