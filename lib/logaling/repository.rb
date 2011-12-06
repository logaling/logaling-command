# -*- coding: utf-8 -*-
require "logaling/glossary_db"

module Logaling
  class Repository
    def initialize(path)
      @path = path
    end

    def lookup(source_term, source_language, target_language, glossary)
      raise GlossaryDBNotFound unless File.exists?(logaling_db_home)

      terms = []
      Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
        terms = db.lookup(source_term)
        terms.delete_if{|term| term[:source_language] != source_language } if source_language
        terms.delete_if{|term| term[:target_language] != target_language } if target_language
        if glossary && !terms.empty?
          # order by glossary
          specified = terms.select{|term| term[:name] == glossary}
          other = terms.select{|term| term[:name] != glossary}
          terms = specified.concat(other)
        end
      end
      terms
    end

    def index
      projects = Dir.glob(File.join(@path, "projects", "*"))

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
    def get_glossaries(path)
      glob_list = %w(yml tsv csv).map{|type| File.join(path, "glossary", "*.#{type}") }
      Dir.glob(glob_list).map do |file|
        name, source_language, target_language = File::basename(file, ".*").split(".")
        [Glossary.new(name, source_language, target_language).load, name, source_language, target_language] 
      end
    end

    def logaling_db_home
      File.join(@path, "db")
    end
  end
end
