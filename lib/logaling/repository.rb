# -*- coding: utf-8 -*-
require "fileutils"
require "logaling/glossary_db"

module Logaling
  class Repository
    def initialize(path)
      @path = path
    end

    def register(dot_logaling_path, register_name)
      FileUtils.mkdir_p(logaling_projects_path) unless File.exist?(logaling_projects_path)
      symlink_path = File.join(logaling_projects_path, register_name)
      unless File.exists?(symlink_path)
        FileUtils.ln_s(dot_logaling_path, symlink_path)
      else
        raise GlossaryAlreadyRegistered, register_name
      end
    end

    def unregister(register_name)
      symlink_path = File.join(logaling_projects_path, register_name)
      if File.exists?(symlink_path)
        FileUtils.remove_entry_secure(symlink_path, true)
      else
        raise GlossaryNotFound, register_name
      end
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

    def registered_project_counts
      Dir.entries(logaling_projects_path).reject{|dir| dir.sub(/[\.]+/, '').empty?}.size
    end

    def config_path
      path = File.join(@path, "config")
      File.exist?(path) ? path : nil
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

    def logaling_projects_path
      File.join(@path, "projects")
    end
  end
end
