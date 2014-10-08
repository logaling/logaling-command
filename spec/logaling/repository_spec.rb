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
require 'yaml'
require "fileutils"

module Logaling
  describe Repository do
    let(:logaling_home) { @logaling_home }
    let(:repository) { Logaling::Repository.new(logaling_home) }
    let(:glossary) { repository.find_project('spec').glossary('en', 'ja') }
    let(:glossary_source_path) { glossary.glossary_source.source_path }
    let(:glossary_source_absolute_path) { glossary.glossary_source.absolute_path }

    before do
      FileUtils.rm_rf(File.join(logaling_home, 'projects', 'spec'), :secure => true)
      FileUtils.mkdir_p(File.join(logaling_home, 'projects', 'spec'))
      repository.index
    end

    describe '#lookup' do
      context 'with arguments show existing bilingual pair' do
        before do
          glossary.add("user-logaling", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling", "ユーザー", "")
          allow(File).to receive_message_chain(:mtime).and_return(Time.now - 1)
          repository.index
          @terms = repository.lookup("user-logaling", glossary)
        end

        it 'succeed at find by term' do
          expect(@terms.size).to eq(2)
        end
      end

      context 'with dictionary option' do
        before do
          glossary.add("user", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling test", "ユーザーてすと", "")
          glossary.add("ゆーざ", "test user-logaling test text", "")
          allow(File).to receive_message_chain(:mtime).and_return(Time.now - 1)
          repository.index
          options = {"dictionary"=>true}
          @terms = repository.lookup("user-logaling", glossary, options)
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
          expect(@terms).to eq(@result)
        end
      end

      context 'with fixed option' do
        let(:annotation_word) { Logaling::Glossary::SUPPORTED_ANNOTATION.first }
        before do
          glossary.add("user", "ユーザ", "ユーザーではない")
          glossary.add("user-logaling", "ユーザ", "ユーザーと迷い中 #{annotation_word}")
          allow(File).to receive_message_chain(:mtime).and_return(Time.now - 1)
          repository.index
          options = {"fixed" => true}
          @terms = repository.lookup("user", glossary, options)
          @result = [{
            :glossary_name=>"spec",
            :source_language=>"en",
            :target_language=>"ja",
            :source_term=>"user",
            :snipped_source_term=>["", {:keyword=>"user"}],
            :target_term=>"ユーザ",
            :snipped_target_term=>["ユーザ"],
            :note=>"ユーザーではない"}]
        end

        it 'succeed at find by term without include annotation' do
          expect(@terms).to eq(@result)
        end

      end

      context 'when tsv file as glossary exists' do
        let(:tsv_path) { glossary_source_absolute_path.sub(/yml$/, 'tsv') }

        before do
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "test-logaling\tユーザー\ntest-logaling\tユーザ"}
          repository.index
          @terms = repository.lookup("test-logaling", glossary)
        end

        it 'succeed at find by term' do
          expect(@terms.size).to eq(2)
        end

        after do
          FileUtils.rm_rf(tsv_path, :secure => true)
        end
      end
    end

    describe '#index' do
      let(:tsv_path) { File.join(File.dirname(glossary_source_absolute_path), "spec.en.ja.tsv") }
      let(:csv_path) { File.join(File.dirname(glossary_source_absolute_path), "spec.en.ja.csv") }

      context 'when yml file as glossary exists' do
        before do
          File.open(glossary_source_absolute_path, 'w') do |f|
            YAML.dump([], f)
          end
          glossary.add("spec_logaling", "スペック", "備考")
          repository.index
          @terms = repository.lookup("spec_logaling", glossary)
        end

        it 'glossaries should be indexed' do
          expect(@terms.size).to eq(1)
        end

        after do
          FileUtils.rm_rf(glossary_source_absolute_path, :secure => true)
        end
      end

      context 'when tsv file as glossary exists' do
        before do
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "user-logaling\tユーザ"}
          repository.index
          @terms = repository.lookup("user-logaling", glossary)
        end

        it 'glossaries should be indexed' do
          expect(@terms.size).to eq(1)
        end

        after do
          FileUtils.rm_rf(tsv_path, :secure => true)
        end
      end

      context 'when csv file as glosary exists' do
        before do
          FileUtils.touch(csv_path)
          File.open(csv_path, "w"){|f| f.puts "test_logaling,テスト"}
          repository.index
          @terms = repository.lookup("test_logaling", glossary)
        end

        it 'glossaries should be indexed' do
          expect(@terms.size).to eq(1)
        end

        after do
          FileUtils.rm_rf(csv_path, :secure => true)
        end
      end
    end

    describe "#create_personal_repository" do
      let(:glossary_name) { "personal_project" }
      let(:source_language) { "en" }
      let(:target_language) { "ja" }
      before do
        FileUtils.rm_rf(File.join(logaling_home, 'personal'), :secure => true)
        repository.create_personal_project(glossary_name, source_language, target_language)
      end

      context "when just create personal project" do
        before do
          glossary = repository.find_glossary(glossary_name, source_language, target_language)
          Logaling::GlossaryDB.open(repository.logaling_db_home, "utf8") do |db|
            @ret = db.glossary_source_exist?(glossary.glossary_source)
          end
        end

        it "should not be indexed on db" do
          expect(@ret).to be_falsey
        end
      end

      context "when create personal project and index" do
        before do
          glossary = repository.find_glossary(glossary_name, source_language, target_language)
          glossary.index!
          Logaling::GlossaryDB.open(repository.logaling_db_home, "utf8") do |db|
            @ret = db.glossary_source_exist?(glossary.glossary_source)
          end
        end

        it "should be indexed on db" do
          expect(@ret).to be_truthy
        end
      end
      after do
        repository.remove_personal_project(glossary_name, source_language, target_language)
      end
    end

    describe "#remove_personal_project" do
      let(:rm_glossary_name) { "rm_personal_project" }
      let(:rm_source_language) { "en" }
      let(:rm_target_language) { "ja" }
      before do
        FileUtils.rm_rf(File.join(logaling_home, 'personal'), :secure => true)
        repository.create_personal_project(rm_glossary_name, rm_source_language, rm_target_language)
        repository.index
      end

      context "when target personal project exists" do
        before do
          repository.remove_personal_project(rm_glossary_name, rm_source_language, rm_target_language)
          @projects = repository.projects
        end

        it "should remove personal project" do
          expect(@projects.size).to eq(1)
        end
      end

      context "when target personal project not exist" do
        it "should raise Logaling::GlossaryNotFound" do
          @name = rm_glossary_name + "foo"
          expect{
            repository.remove_personal_project(@name, rm_source_language, rm_target_language)
          }.to raise_error(Logaling::GlossaryNotFound)
        end
      end
    end

    after do
      FileUtils.rm_rf(File.join(logaling_home, 'projects', 'spec'), :secure => true)
    end
  end
end
