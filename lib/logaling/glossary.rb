# -*- coding: utf-8 -*-
#require "logaling-command/version"

require 'psych'
require "yaml"
require "fileutils"

module Logaling
  class Glossary
    def self.build_path(glossary, source_language, target_language)
      dir, file = File::split(glossary)
      if dir == "."
        fname = [glossary, source_language, target_language].join(".")
        return File.join(LOGALING_HOME, "#{fname}.yml")
      else
        return glossary
      end
    end

    def initialize(glossary, source_language, target_language)
      @path = Glossary.build_path(glossary, source_language, target_language)
      @glossary = glossary
      @source_language = source_language
      @target_language = target_language
    end

    def create
      check_glossary_unexists

      dirname = File::dirname(@path)
      FileUtils.mkdir_p(dirname)
      FileUtils.touch(@path)
    end

    def add(source_term, target_term, note)
      check_glossary_exists

      if bilingual_pair_exists?(source_term, target_term)
        puts "[#{source_term}] [#{target_term}] pair is already exist}"
        return
      end

      glossary = YAML::load_file(@path)
      glossary << build_term(source_term, target_term, note)

      File.open(@path, "w") do |f|
        f.puts(glossary.to_yaml)
      end
    end

    def update(source_term, target_term, new_target_term, note)
      check_glossary_exists

      if bilingual_pair_exists?(source_term, new_target_term)
        puts "[#{source_term}] [#{new_target_term}] pair is already exist}"
        return
      end

      glossary = YAML::load_file(@path)
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary[target_index] = rebuild_term(glossary[target_index], source_term, new_target_term, note)
        File.open(@path, "w") do |f|
          f.puts glossary.to_yaml
        end
      else
        puts "source_term:#{source_term} target_term:#{target_term} not found in glossary #{@path}"
      end
    end

    def delete(source_term, target_term)
      check_glossary_exists

      glossary = YAML::load_file(@path)
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary.delete_at(target_index)
        File.open(@path, "w") do |f|
          f.puts glossary.to_yaml
        end
      else
        puts "source_term:#{source_term} target_term:#{target_term} not found in glossary #{@path}"
      end
    end

    def lookup(source_term)
      check_glossary_exists

      glossarydb = Logaling::GlossaryDB.new
      glossarydb.open(LOGALING_DB_HOME, "utf8") do |db|
        glossaries = db.lookup(source_term)
        glossaries.reject! do |term|
          term[:source_language] != @source_language || term[:target_language] != @target_language
        end
        if glossaries.empty?
          puts "source_term <#{source_term}> not found"
          return
        end
        # order by glossary
        specified = glossaries.select{|term| term[:name] == @glossary}
        other = glossaries.select{|term| term[:name] != @glossary}
        glossaries = specified.concat(other)

        puts "\nlookup word : #{source_term}"
        glossaries.each do |term|
          puts "\n  #{term[:source_term]}\n"
          puts "  #{term[:target_term]}\n"
          puts "    note:#{term[:note]}"
          puts "    glossary:#{term[:name]}"
        end
      end
    end

    private
    def build_term(source_term, target_term, note)
      {'source_term' => source_term, 'target_term' => target_term, 'note' => note}
    end

    def rebuild_term(current, source_term, target_term, note)
      note = current['note'] if note == ""
      target_term = current['target_term'] if target_term == ""
      build_term(source_term, target_term, note)
    end

    def find_term_index(glossary_yml, source_term, target_term)
      glossary_yml.find_index do |term|
        term['source_term'] == source_term && term['target_term'] == target_term
      end
    end

    def bilingual_pair_exists?(source_term, target_term)
      target_terms(source_term).any?{|data| data['target_term'] == target_term }
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

    def target_terms(source_term, path=@path)
      target_terms = []
      glossaly = YAML::load_file(path) || []
      glossaly.each do |term|
        target_terms << term if term['source_term'] == source_term
      end
      target_terms
    end

    def lookup_files
      file_list = Dir.glob("#{LOGALING_HOME}/*.#{@source_language}.#{@target_language}.yml")
      if glossary_index = file_list.index(@path)
        file_list.delete_at(glossary_index)
      end
      file_list.unshift(@path)
      return file_list
    end
  end
end
