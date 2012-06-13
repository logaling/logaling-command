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
    VERSION = 1

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
      unless latest_version?
        remove_schema
        populate_schema
        update_version_to_latest
      end
    end

    def close
      @database.close
      @database = nil
    end

    def deindex_glossary(glossary_name, glossary_source)
      delete_translations_by_glossary_source(glossary_source)
      delete_glossary(glossary_name)
      delete_glossary_source(glossary_source)
    end

    def index_glossary(glossary_name, glossary_source, source_language, target_language, indexed_at)
      delete_terms if offline_index?

      deindex_glossary(glossary_name, glossary_source)

      add_glossary_source(glossary_source, indexed_at)
      add_glossary(glossary_name)
      GlossarySource.load(glossary_source).each do |term|
        source_term = term['source_term']
        target_term = term['target_term']
        note = term['note']
        add_translation(glossary_name, glossary_source, source_language, target_language, source_term, target_term, note)
      end

      create_terms if offline_index?
    end

    def lookup(source_term, glossary_source=nil)
      records_selected = Groonga["translations"].select do |record|
        conditions = [record.source_term =~ source_term]
        if glossary_source
          conditions << (record.source_language =~ glossary_source.source_language) if glossary_source.source_language
          conditions << (record.target_language =~ glossary_source.target_language) if glossary_source.target_language
        end
        conditions
      end
      if glossary_source
        specified_glossary = records_selected.select do |record|
          record.glossary == glossary_source.glossary
        end
        specified_glossary.each do |record|
          record.key._score += 10
        end
      end
      records = records_selected.sort([
        {:key=>"_score", :order=>'descending'},
        {:key=>"glossary", :order=>'ascending'},
        {:key=>"source_term", :order=>'ascending'},
        {:key=>"target_term", :order=>'ascending'}])

      options = {:width => 5000,
                 :html_escape => true,
                 :normalize => true}
      snippet = records_selected.expression.snippet(["<snippet>", "</snippet>"], options)
      struct_result(records, snippet)
    ensure
      snippet.close if snippet
      records_selected.expression.close if records_selected
      specified_glossary.expression.close if specified_glossary
    end

    def lookup_dictionary(search_word)
      records_selected_source = Groonga["translations"].select do |record|
        target = record.match_target do |match_record|
          match_record.source_term * 2
        end
        target =~ search_word
      end
      completely_match = records_selected_source.select do |record|
        record.source_term == search_word
      end
      completely_match.each do |record|
        record.key._score += 10
      end

      records_selected_target = Groonga["translations"].select do |record|
        record.target_term =~ search_word
      end

      records_selected = records_selected_target.union!(records_selected_source)
      records = records_selected.sort([
        {:key=>"_score", :order=>'descending'},
        {:key=>"source_term", :order=>'ascending'},
        {:key=>"target_term", :order=>'ascending'}])

      options = {:width => 5000,
                 :html_escape => true,
                 :normalize => true}
      snippet = records_selected.expression.snippet(["<snippet>", "</snippet>"], options)

      struct_result(records, snippet)
    ensure
      snippet.close if snippet
      records_selected.expression.close if records_selected
    end

    def translation_list(glossary, order='ascending')
      records_raw = Groonga["translations"].select do |record|
        [
          record.glossary == glossary.name,
          record.source_language == glossary.source_language,
          record.target_language == glossary.target_language
        ]
      end

      records = records_raw.sort([
        {:key => "source_term", :order => order},
        {:key => "target_term", :order => order}
      ])

      struct_result(records)
    ensure
      records_raw.expression.close
    end

    def get_bilingual_pair(source_term, target_term, glossary, note=nil)
      records = Groonga["translations"].select do |record|
        if note
          [
            record.glossary == glossary,
            record.source_term == source_term,
            record.target_term == target_term,
            record.note == note
          ]
        else
          [
            record.glossary == glossary,
            record.source_term == source_term,
            record.target_term == target_term
          ]
        end
      end
      struct_result(records)
    ensure
      records.expression.close
    end

    def glossary_source_exist?(glossary_source, indexed_at)
      glossary = Groonga["glossary_sources"].select do |record|
        [
          record.key == glossary_source,
          record.indexed_at == indexed_at
        ]
      end
      !glossary.size.zero?
    ensure
      glossary.expression.close
    end

    def get_all_glossary_source
      Groonga["glossary_sources"].sort([
        {:key=>"_key", :order=>'ascending'}
      ]).map{|record| record.key}
    end

    def glossary_sources_related_on_glossary(glossary_string)
      records = Groonga["glossary_sources"].select do |record|
        [record.key =~ glossary_string]
      end
      records.map{|record| record.key.key }
    end

    def get_all_glossary
      Groonga["glossaries"].sort([
        {:key=>"_key", :order=>'ascending'}
      ]).map{|record| record.key}
    end

    private
    def delete_glossary_source(glossary_source)
      records = Groonga["glossary_sources"].select do |record|
        record.key == glossary_source
      end

      records.each do |record|
        record.key.delete
      end
    ensure
      records.expression.close
    end

    def add_glossary_source(glossary_source, indexed_at)
      Groonga["glossary_sources"].add(glossary_source, :indexed_at => indexed_at)
    end

    def delete_glossary(glossary_name)
      records = Groonga["glossaries"].select do |record|
        record.key == glossary_name
      end

      records.each do |record|
        record.key.delete
      end
    ensure
      records.expression.close
    end

    def add_glossary(glossary_name)
      Groonga["glossaries"].add(glossary_name)
    end

    def delete_translations_by_glossary_source(glossary_source)
      records = Groonga["translations"].select do |record|
        record.glossary_source == glossary_source
      end

      records.each do |record|
        record.key.delete
      end
    ensure
      records.expression.close
    end

    def delete_terms
      if Groonga['terms']
        Groonga::Schema.define do |schema|
          schema.remove_table("terms")
        end
      end
    end

    def create_terms
      Groonga::Schema.define do |schema|
        schema.create_table("terms",
                            :type => :patricia_trie,
                            :key_type => "ShortText",
                            :key_normalize => true,
                            :default_tokenizer => "TokenBigram") do |table|
          table.index("translations.source_term")
          table.index("translations.target_term")
        end
      end
    end

    def add_translation(glossary_name, glossary_source, source_language, target_language, source_term, target_term, note)
      Groonga["translations"].add(:glossary => glossary_name,
                                  :glossary_source => glossary_source,
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

        schema.create_table("glossary_sources",
                           :type => :hash,
                           :key_type => "ShortText") do |table|
          table.time("indexed_at")
        end

        schema.create_table("glossaries",
                           :type => :hash,
                           :key_type => "ShortText") do |table|
        end

        schema.create_table("translations") do |table|
          table.reference("glossary", "glossaries")
          table.reference("glossary_source", "glossary_sources")
          table.short_text("source_language")
          table.short_text("target_language")
          table.short_text("source_term")
          table.text("target_term")
          table.text("note")
        end
      end
      create_terms
    end

    def remove_schema
      Groonga::Schema.define do |schema|
        %w(configurations translations glossaries glossary_sources terms).each do |table|
          schema.remove_table(table) if Groonga[table]
        end
      end
    end

    def closed?
      @database.nil? or @database.closed?
    end

    def struct_result(records, snippet=nil)
      records.map do |record|
        term = record.key
        snipped_source_term = snippet ? struct_snipped_term(term.source_term, snippet) : []
        snipped_target_term = snippet ? struct_snipped_term(term.target_term, snippet) : []
        {:glossary_name => term.glossary.key,
         :source_language => term.source_language,
         :target_language => term.target_language,
         :source_term => term.source_term,
         :snipped_source_term => snipped_source_term,
         :target_term => term.target_term,
         :snipped_target_term => snipped_target_term,
         :note => term.note || ''}
      end
    end

    def struct_snipped_text(snipped_text)
      return [] if snipped_text.empty?
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

    def struct_snipped_term(term, snippet)
      snipped_text = snippet.execute(term).join
      snipped_text.empty? ? [term] : struct_snipped_text(snipped_text)
    end

    def latest_version?
      current_version == VERSION
    end

    def current_version
      Groonga["configurations"] ? get_config("version").to_i : 0
    end

    def update_version_to_latest
      add_config("version", VERSION.to_s)
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
    ensure
      records.expression.close
    end

    def add_config(conf_key, conf_value)
      Groonga["configurations"].add(:conf_key => conf_key, :conf_value => conf_value)
    end

    def offline_index?
      # use online index if LOGALING_OFFLINE_INDEX=no
      ENV["LOGALING_OFFLINE_INDEX"] != "no"
    end
  end
end
