# -*- encoding: utf-8 -*-

require 'psych'
require "yaml"
require "fileutils"
require 'groonga'

module Logaling
  class GlossaryDB
    def initialize()
      @database = nil
    end

    def open(base_path, encoding)
      reset_context(encoding)
      path = File.join(base_path, "logaling.db")
      if File.exist?(path)
        @database = Groonga::Database.open(path)
        remove_schema
        populate_schema
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

    def close
      @database.close
      @database = nil
    end

    def closed?
      @database.nil? or @database.closed?
    end

    def load_glossaries(path)
      file_list = Dir.glob("#{path}/*.yml")
      file_list.each do |file|
        name, from_language, to_language = File::basename(file, "yml").split(".")
        glossary = YAML::load_file(file)
        next if !glossary
        glossary.each do |term|
          keyword = term['keyword']
          translation = term['translation']
          note = term['note']
          add_glossary(name, from_language, to_language, keyword, translation, note)
        end
      end
    end

    private
    def add_glossary(name, from_language, to_language, keyword, translation, note)
      attributes = {
        :name => name
      }
      Groonga["glossaries"].add(:name => name,
                             :from_language => from_language,
                             :to_language => to_language,
                             :keyword => keyword,
                             :translation => translation,
                             :note => note,
                            )
    end

    def reset_context(encoding)
      Groonga::Context.default_options = {:encoding => encoding}
      Groonga::Context.default = nil
    end

    def populate(path)
      @database = Groonga::Database.create(:path => path)
      populate_schema
    end

    def populate_schema
      Groonga::Schema.define do |schema|
        schema.create_table("glossaries",
                            :force => true) do |table|
           table.short_text("name")
           table.short_text("from_language")
           table.short_text("to_language")
           table.short_text("keyword")
           table.text("translation")
           table.text("note")
        end

        schema.create_table("terms",
                            :force => true,
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :key_normalize => true,
                            :default_tokenizer => "TokenBigram") do |table|
          table.index("glossaries.keyword")
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
