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

require File.join(File.dirname(__FILE__), "..", "spec_helper")
require "fileutils"

module Logaling
  describe Repository do
    let(:project) { "spec" }
    let(:logaling_home) { @logaling_home }
    let(:db_home) { File.join(logaling_home, "db") }
    let(:repository) { Logaling::Repository.new(logaling_home) }
    let(:glossary) { repository.find_project(project).find_glossary('en', 'ja') }
    let(:glossary_source) { glossary.glossary_source }
    let(:glossary_source_path) { glossary_source.source_path }

    before do
      FileUtils.remove_entry_secure(File.join(logaling_home, 'projects', 'spec'), true)
      FileUtils.mkdir_p(File.join(logaling_home, 'projects', 'spec'))
    end

    describe '#lookup' do
      context 'with arguments show existing bilingual pair' do
        before do
          glossary.add("user-logaling", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling", "ユーザー", "")
          File.stub!(:mtime).and_return(Time.now - 1)
          repository.index
          @terms = repository.lookup("user-logaling", glossary)
        end

        it 'succeed at find by term' do
          @terms.size.should == 2
        end
      end

      context 'with dictionary option' do
        before do
          glossary.add("user", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling test", "ユーザーてすと", "")
          glossary.add("ゆーざ", "test user-logaling test text", "")
          File.stub!(:mtime).and_return(Time.now - 1)
          repository.index
          @terms = repository.lookup("user-logaling", glossary, true)
          @result = [{
            :glossary_name=>"spec",
            :source_language=>"en",
            :target_language=>"ja",
            :source_term=>"user-logaling",
            :snipped_source_term=>["", {:keyword=>"user-logaling"}],
            :target_term=>"ユーザ",
            :snipped_target_term=>["ユーザ"],
            :note=>"ユーザーではない"},
            {
            :glossary_name=>"spec",
            :source_language=>"en",
            :target_language=>"ja",
            :source_term=>"user-logaling test",
            :snipped_source_term=>["", {:keyword=>"user-logaling"}, " test"],
            :target_term=>"ユーザーてすと",
            :snipped_target_term=>["ユーザーてすと"],
            :note=>""},
            {
            :glossary_name=>"spec",
            :source_language=>"en",
            :target_language=>"ja",
            :source_term=>"ゆーざ",
            :snipped_source_term=>["ゆーざ"],
            :target_term=>"test user-logaling test text",
            :snipped_target_term=>["test", {:keyword=>" user-logaling"}, " test text"],
            :note=>""}]
        end

        it 'succeed at find by term' do
          @terms.should == @result
        end
      end

      context 'when tsv file as glossary exists' do
        let(:tsv_path) { glossary_source_path.sub(/yml$/, 'tsv') }

        before do
          FileUtils.mkdir_p(File.dirname(tsv_path))
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "test-logaling\tユーザー\ntest-logaling\tユーザ"}
          repository.index
          @terms = repository.lookup("test-logaling", glossary)
        end

        it 'succeed at find by term' do
          @terms.size.should == 2
        end

        after do
          FileUtils.remove_entry_secure(tsv_path, true)
        end
      end
    end

    describe '#index' do
      let(:logaling_db) { Logaling::GlossaryDB.new }
      let(:tsv_path) { File.join(File.dirname(glossary_source_path), "spec.en.ja.tsv") }
      let(:csv_path) { File.join(File.dirname(glossary_source_path), "spec.en.ja.csv") }

      context 'when yml file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_source_path))
          FileUtils.touch(glossary_source_path)
          glossary.add("spec_logaling", "スペック", "備考")
          repository.index
          @terms = repository.lookup("spec_logaling", glossary)
        end

        it 'glossaries should be indexed' do
          @terms.size.should == 1
        end

        after do
          FileUtils.remove_entry_secure(glossary_source_path, true)
        end
      end

      context 'when tsv file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_source_path))
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "user-logaling\tユーザ"}
          repository.index
          @terms = repository.lookup("user-logaling", glossary)
        end

        it 'glossaries should be indexed' do
          @terms.size.should == 1
        end

        after do
          FileUtils.remove_entry_secure(tsv_path, true)
        end
      end

      context 'when csv file as glosary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_source_path))
          FileUtils.touch(csv_path)
          File.open(csv_path, "w"){|f| f.puts "test_logaling,テスト"}
          repository.index
          @terms = repository.lookup("test_logaling", glossary)
        end

        it 'glossaries should be indexed' do
          @terms.size.should == 1
        end

        after do
          FileUtils.remove_entry_secure(csv_path, true)
        end
      end
    end

    after do
      FileUtils.remove_entry_secure(File.join(logaling_home, 'projects', 'spec'), true)
    end
  end
end
