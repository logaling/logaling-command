# -*- coding: utf-8 -*-
require 'psych'
require "yaml"
require "fileutils"
require "logaling/glossary_db"

module Logaling
  class Glossary
    def self.build_path(glossary, source_language, target_language)
      fname = [glossary, source_language, target_language].join(".")
      File.join(LOGALING_HOME, "projects", glossary, "glossary", "#{fname}.yml")
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
        raise TermError, "[#{source_term}] [#{target_term}] pair already exists"
      end

      glossary = load_glossary_yml
      glossary << build_term(source_term, target_term, note)

      dump_glossary(glossary)
    end

    def update(source_term, target_term, new_target_term, note)
      check_glossary_exists

      if bilingual_pair_exists?(source_term, new_target_term)
        raise TermError, "[#{source_term}] [#{new_target_term}] pair already exists"
      end

      glossary = load_glossary_yml
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary[target_index] = rebuild_term(glossary[target_index], source_term, new_target_term, note)
        dump_glossary(glossary)
      else
        raise TermError, "source_term:#{source_term} target_term:#{target_term} not found in glossary #{@path}"
      end
    end

    def delete(source_term, target_term)
      check_glossary_exists

      glossary = load_glossary_yml
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary.delete_at(target_index)
        dump_glossary(glossary)
      else
        raise TermError, "source_term:#{source_term} target_term:#{target_term} not found in glossary #{@path}"
      end
    end

    def lookup(source_term)
      check_glossary_exists

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.lookup(source_term)
        terms.reject! do |term|
          term[:source_language] != @source_language || term[:target_language] != @target_language
        end
        unless terms.empty?
          # order by glossary
          specified = terms.select{|term| term[:name] == @glossary}
          other = terms.select{|term| term[:name] != @glossary}
          terms = specified.concat(other)
        end
      end
      terms
    end

    def index
      projects = Dir.glob(File.join(LOGALING_HOME, "projects", "*"))

      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        db.recreate_table
        projects.each do |project|
          db.index_glossaries(File.join(project, "glossary"))
        end
      end
    end

    private
    def load_glossary_yml
      YAML::load_file(@path) || []
    end

    def logaling_db_home
      File.join(LOGALING_HOME, "db")
    end

    def build_term(source_term, target_term, note)
      note ||= ''
      {'source_term' => source_term, 'target_term' => target_term, 'note' => note}
    end

    def rebuild_term(current, source_term, target_term, note)
      note = current['note'] if note.nil? || note == ""
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

    def check_glossarydir_unexists
      unless File.exists?(File.dirname(@path))
        raise CommandFailed, "glossary path #{File.dirname(@path)} not found"
      end
    end

    def check_glossary_unexists
      check_glossarydir_unexists
      raise CommandFailed, "glossary #{@path} already exists" if File.exists?(@path)
    end

    def check_glossary_exists
      check_glossarydir_unexists
      FileUtils.touch(@path) unless File.exists?(@path)
    end

    def target_terms(source_term, path=@path)
      target_terms = []
      glossaly = YAML::load_file(path) || []
      glossaly.each do |term|
        target_terms << term if term['source_term'] == source_term
      end
      target_terms
    end

    def dump_glossary(glossary)
      File.open(@path, "w") do |f|
        f.puts(glossary.to_yaml)
      end
    end
  end
end
