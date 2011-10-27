# -*- encoding: utf-8 -*-
#require "logaling-command/version"

require 'psych'
require "yaml"
require "fileutils"

module Logaling
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

      if bilingual_pair_exists?(keyword, translation)
        # key-translation pair that already exist
        puts "[#{keyword}] [#{translation}] pair is already exist}"
        return
      end

      File.open(@path, "a") do |f|
        term = [ build_term(keyword, translation, note) ]
        f.puts(term.to_yaml.gsub("---\n", ""))
      end
    end

    def update(keyword, translation, new_translation, note)
      check_glossary_exists

      if bilingual_pair_exists?(keyword, new_translation)
        # key-new_translation pair that already exist
        puts "[#{keyword}] [#{new_translation}] pair is already exist}"
        return
      end

      glossary = YAML::load_file(@path)
      target_index = find_term_index(glossary, keyword, translation)
      if target_index
        glossary[target_index] = rebuild_term(glossary[target_index], keyword, new_translation, note)
        File.open(@path, "w") do |f|
          f.puts glossary.to_yaml
        end
      else
        puts "keyword:#{keyword} translation:#{translation} not found in glossary #{@path}"
      end
    end

    def delete(keyword, translation)
      check_glossary_exists

      glossary = YAML::load_file(@path)
      target_index = find_term_index(glossary, keyword, translation)
      if target_index
        glossary.delete_at(target_index)
        File.open(@path, "w") do |f|
          f.puts glossary.to_yaml
        end
      else
        puts "keyword:#{keyword} translation:#{translation} not found in glossary #{@path}"
      end
    end

    def lookup(keyword, glossary)
      check_glossary_exists

      glossarydb = Logaling::GlossaryDB.new
      glossarydb.open(LOGALING_DB_HOME, "utf8") do |db|
        glossaries = db.lookup(glossary, keyword)
        glossaries.reject! do |term|
          term[:from_language] != @from_language || term[:to_language] != @to_language
        end
        if glossaries.empty?
          puts "keyword #{keyword} not found"
          return
        end

        puts "\n#{keyword}\n"
        glossaries.each do |term|
          puts "\n  #{term[:keyword]}\n"
          puts "  #{term[:translation]}\n"
          puts "    備考:#{term[:note]}"
          puts "    用語集:#{term[:name]}"
        end
      end
    end

    private
    def build_term(keyword, translation, note)
      {'keyword' => keyword, 'translation' => translation, 'note' => note}
    end

    def rebuild_term(current, keyword, translation, note)
      note = current['note'] if note == ""
      translation = current['translation'] if translation == ""
      build_term(keyword, translation, note)
    end

    def find_term_index(glossary_yml, keyword, translation)
      glossary_yml.find_index do |term|
        term['keyword'] == keyword && term['translation'] == translation
      end
    end

    def bilingual_pair_exists?(keyword, translation)
      translations(keyword).any?{|data| data['translation'] == translation }
    end

    def exist?
      File.exists?(@path)
    end

    def check_glossary_unexists
      raise CommandFailed, "glossary #{@path} is already exists" if exist?
    end

    def check_glossary_exists
      raise CommandFailed, "glossary #{@path} not found" unless exist?
    end

    def translations(keyword, path=@path)
      translations = []
      glossaly = YAML::load_file(path) || []
      glossaly.each do |term|
        translations << term if term['keyword'] == keyword
      end
      translations
    end

    def lookup_files
      file_list = Dir.glob("#{LOGALING_HOME}/*.#{@from_language}.#{@to_language}.yml")
      if glossary_index = file_list.index(@path)
        file_list.delete_at(glossary_index)
      end
      file_list.unshift(@path)
      return file_list
    end
  end
end
