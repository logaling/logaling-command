# -*- coding: utf-8 -*-
#
# Copyright (C) 2011  Miho SUZUKI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'groonga'
require 'cgi'

module Logaling
  class GlossaryDB
    @@version = 1

    def self.open(base_path, encoding, &blk)
      blk ? GlossaryDB.new.open(base_path, encoding, &blk) : GlossaryDB.new.open(base_path, encoding)
    end

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

    def recreate_table
      version = Groonga["configurations"] ? get_config("version") : 0
      if version.to_i != @@version
        remove_schema
        populate_schema
        add_config("version", @@version.to_s)
      end
    end

    def close
      @database.close
      @database = nil
    end

    def index_glossary(glossary, glossary_name, source_language, target_language)
      add_glossary(glossary_name)
      glossary.each do |term|
        source_term = term['source_term']
        target_term = term['target_term']
        note = term['note']
        add_translations(glossary_name, source_language, target_language, source_term, target_term, note)
      end
    end

    def lookup(source_term, source_language, target_language, glossary)
      records_selected = Groonga["translations"].select do |record|
        conditions = [record.source_term =~ source_term]
        conditions << (record.source_language =~ source_language) if source_language
        conditions << (record.target_language =~ target_language) if target_language
        conditions
      end
      specified_glossary = records_selected.select do |record|
        record.glossary == glossary
      end
      specified_glossary.each do |record|
        record.key._score += 10
      end
      records = records_selected.sort([
        {:key=>"_score", :order=>'descending'},
        {:key=>"glossary", :order=>'ascending'},
        {:key=>"source_term", :order=>'ascending'},
        {:key=>"target_term", :order=>'ascending'}])

      options = {:width => 100,
                 :html_escape => true,
                 :normalize => true}
      snippet = records_selected.expression.snippet(["<snippet>", "</snippet>"], options)

      snipped_source_term = []
      records.map do |record|
        term = record.key
        snipped_text = snippet.execute(term.source_term).join
        {:glossary_name => term.glossary.key,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :snipped_source_term => struct_snipped_text(snipped_text),
         :target_term => term.target_term,
         :note => term.note || ''}
      end
    end

    def list(glossary, source_language, target_language)
      records_raw = Groonga["translations"].select do |record|
        [
          record.glossary == glossary,
          record.source_language == source_language,
          record.target_language == target_language
        ]
      end

      records = records_raw.sort([
        {:key=>"source_term", :order=>'ascending'},
        {:key=>"target_term", :order=>'ascending'}])

      records.map do |record|
        term = record.key

        {:glossary_name => term.glossary.key,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :target_term => term.target_term,
         :note => term.note || ''}
      end
    end

    def get_bilingual_pair(source_term, target_term, glossary)
      records = Groonga["translations"].select do |record|
        [
          record.glossary == glossary,
          record.source_term == source_term,
          record.target_term == target_term
        ]
      end

      records.map do |record|
        term = record.key

        {:glossary_name => term.glossary,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :target_term => term.target_term,
         :note => term.note || ''}
      end
    end

    def get_bilingual_pair_with_note(source_term, target_term, note, glossary)
      records = Groonga["translations"].select do |record|
        [
          record.glossary == glossary,
          record.source_term == source_term,
          record.target_term == target_term,
          record.note == note
        ]
      end

      records.map do |record|
        term = record.key

        {:glossary_name => term.glossary,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :target_term => term.target_term,
         :note => term.note || ''}
      end
    end

    private
    def add_glossary(glossary_name)
      name = Groonga["glossaries"].select{|record| record.key == glossary_name}
      if name.size.zero?
        now = Time.now
        Groonga["glossaries"].add(glossary_name, :indexed_at => now)
      end
    end

    def add_translations(glossary_name, source_language, target_language, source_term, target_term, note)
      Groonga["translations"].add(:glossary => glossary_name,
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
        schema.create_table("configurations") do |table|
          table.short_text("conf_key")
          table.text("conf_value")
        end

        schema.create_table("glossaries",
                           :type => :hash,
                           :key_type => "ShortText") do |table|
          table.time("indexed_at")
        end

        schema.create_table("translations") do |table|
          table.reference("glossary", "glossaries")
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
          table.index("translations.source_term")
        end
      end
    end

    def remove_schema
      Groonga::Schema.define do |schema|
        schema.remove_table("configurations") if Groonga["configurations"]
        schema.remove_table("translations") if Groonga["translations"]
        schema.remove_table("glossaries") if Groonga["glossaries"]
        schema.remove_table("terms") if Groonga["terms"]
      end
    end

    def closed?
      @database.nil? or @database.closed?
    end

    def struct_snipped_text(snipped_text)
      word_list = snipped_text.split(/(<snippet>[^<]*<\/snippet>)/)
      structed_source_term = word_list.map{|word|
        replaced_word = word.sub(/<snippet>([^<]*)<\/snippet>/){|match| $1}
        if replaced_word == word
          CGI.unescapeHTML(word)
        else
          {:keyword => CGI.unescapeHTML(replaced_word)}
        end
      }
      structed_source_term
    end

    def get_config(conf_key)
      records = Groonga["configurations"].select do |record|
        record.conf_key == conf_key
      end
      value = records.map do |record|
        config = record.key
        config.conf_value
      end
      value.size > 0 ? value[0] : ""
    end

    def add_config(conf_key, conf_value)
      Groonga["configurations"].add(:conf_key => conf_key, :conf_value => conf_value)
    end
  end
end
