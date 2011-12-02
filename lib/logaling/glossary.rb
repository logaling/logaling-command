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

    def add(source_term, target_term, note)
      FileUtils.touch(@path) unless File.exists?(@path)

      if bilingual_pair_exists?(source_term, target_term)
        raise TermError, "term '#{source_term}: #{target_term}' already exists in '#{@glossary}'"
      end

      glossary = load_glossary_yml(@path)
      glossary << build_term(source_term, target_term, note)

      dump_glossary(glossary)
    end

    def update(source_term, target_term, new_target_term, note)
      raise GlossaryNotFound unless File.exists?(@path)

      if bilingual_pair_exists?(source_term, new_target_term)
        raise TermError, "term '#{source_term}: #{target_term}' already exists in '#{@glossary}'"
      end

      glossary = load_glossary_yml(@path)
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary[target_index] = rebuild_term(glossary[target_index], source_term, new_target_term, note)
        dump_glossary(glossary)
      else
        raise TermError, "Can't found term '#{source_term}: #{target_term}' in '#{@glossary}'"
      end
    end

    def delete(source_term, target_term)
      raise GlossaryNotFound unless File.exists?(@path)

      glossary = load_glossary_yml(@path)
      target_index = find_term_index(glossary, source_term, target_term)
      if target_index
        glossary.delete_at(target_index)
        dump_glossary(glossary)
      else
        raise TermError, "Can't found term '#{source_term}: #{target_term}' in '#{@glossary}'"
      end
    end

    def lookup(source_term)
      raise GlossaryDBNotFound unless File.exists?(logaling_db_home)

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
          get_glossaries(project).each do |glossary, name, source_language, target_language|
            db.index_glossary(glossary, name, source_language, target_language)
          end
        end
      end
    end

    private
    def load_glossary(file)
      case File.extname(file)
      when ".csv"
        load_glossary_csv(file)
      when ".tsv"
        load_glossary_tsv(file)
      when ".yml"
        load_glossary_yml(file)
      end
    end

    def get_glossaries(path)
      glob_list = %w(yml tsv csv).map{|type| File.join(path, "glossary", "*.#{type}") }
      Dir.glob(glob_list).map do |file|
        name, source_language, target_language = File::basename(file, ".*").split(".")
        [load_glossary(file), name, source_language, target_language]
      end
    end

    def load_glossary_yml(path)
      YAML::load_file(path) || []
    end

    def load_glossary_tsv(path)
      load_glossary_csv(path, "\t")
    end

    def load_glossary_csv(path, sep=",")
      glossary = []
      CSV.open(path, "r",  {:col_sep => sep}) do |csv|
        csv.each do |row|
          glossary << {"source_term" => row[0], "target_term" => row[1], "note" => ""} if row.size >= 2
        end
      end
      glossary
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

    def target_terms(source_term, path=@path)
      target_terms = []
      glossaly_yml = load_glossary_yml(path)
      glossaly_yml.each do |term|
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
