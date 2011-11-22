# -*- coding: utf-8 -*-

require 'psych'
require "yaml"
require "fileutils"
require 'groonga'
require 'csv'

module Logaling
  class GlossaryDB
    def initialize
      @database = nil
    end

    def open(base_path, encoding)
      reset_context(encoding)
      path = File.join(base_path, "logaling.db")
      if File.exist?(path)
        @database = Groonga::Database.open(path)
      else
        FileUtils.mkdir_p(base_path)
        populate(path)
      end
      if block_given?
        begin
          yield(self)
        ensure
          close unless closed?
        end
      end
    end

    def recreate_table(base_path)
      path = File.join(base_path, "logaling.db.tables")
      if File.exist?(path)
        remove_schema
      end
      populate_schema
    end

    def close
      @database.close
      @database = nil
    end

    def closed?
      @database.nil? or @database.closed?
    end

    def get_file_list(path, types)
      glob_list = []
      types.each do |type|
        glob_list << File.join(path, "*.#{type}")
      end
      Dir.glob(glob_list)
    end

    def load_glossary(file)
      case extname = File.extname(file)
      when ".tsv", ".csv"
        sep = extname == ".tsv" ? "\t" : ","
        glossary = []
        CSV.open(file, "r",  {:col_sep => sep}) do |csv|
          csv.each do |row|
            glossary << {"source_term" => row[0], "target_term" => row[1], "note" => ""}
          end
        end
        glossary
      when ".yml"
        YAML::load_file(file)
      end
    end

    def load_glossaries(path)
      file_list = get_file_list(path, ["yml", "tsv", "csv"])
      file_list.each do |file|
        name, source_language, target_language = File::basename(file, ".*").split(".")
        glossary = load_glossary(file)
        next if !glossary
        glossary.each do |term|
          source_term = term['source_term']
          target_term = term['target_term']
          note = term['note']
          add_glossary(name, source_language, target_language, source_term, target_term, note)
        end
      end
    end

    def lookup(source_term)
      records_raw = Groonga["glossaries"].select do |record|
        record.source_term =~ source_term
      end
      records = records_raw.sort([
        {:key=>"name", :order=>'ascending'},
        {:key=>"source_term", :order=>'ascending'},
        {:key=>"target_term", :order=>'ascending'}])

      records.map do |record|
        term = record.key
        {:name => term.name,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :target_term => term.target_term,
         :note => term.note,}
      end
    end

    private
    def add_glossary(name, source_language, target_language, source_term, target_term, note)
      Groonga["glossaries"].add(:name => name,
                                :source_language => source_language,
                                :target_language => target_language,
                                :source_term => source_term,
                                :target_term => target_term,
                                :note => note,
                               )
    end

    def reset_context(encoding)
      Groonga::Context.default_options = {:encoding => encoding}
      Groonga::Context.default = nil
    end

    def populate(path)
      @database = Groonga::Database.create(:path => path)
    end

    def populate_schema
      Groonga::Schema.define do |schema|
        schema.create_table("glossaries") do |table|
          table.short_text("name")
          table.short_text("source_language")
          table.short_text("target_language")
          table.short_text("source_term")
          table.text("target_term")
          table.text("note")
        end

        schema.create_table("terms",
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :key_normalize => true,
                            :default_tokenizer => "TokenBigram") do |table|
          table.index("glossaries.source_term")
        end
      end
    end

    def remove_schema
      Groonga::Schema.define do |schema|
        schema.remove_table("glossaries")
        schema.remove_table("terms")
      end
    end
  end
end
