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
  describe Glossary do
    let(:logaling_home) { @logaling_home }
    let(:logaling_db_home) { File.join(logaling_home, 'db') }
    let(:repository) { Logaling::Repository.new(logaling_home) }
    let(:glossary) { repository.find_project('spec').glossary('en', 'ja') }
    let(:glossary_source_path) { glossary.glossary_source.source_path }
    let(:glossary_source_expand_path) { glossary.glossary_source.expand_path }

    before do
      # clear directories and files
      FileUtils.rm_rf(File.join(logaling_home, 'projects', 'spec'), :secure => true)
      FileUtils.mkdir_p(File.join(logaling_home, 'projects', 'spec', 'glossary'))
      FileUtils.touch(glossary_source_expand_path)
      File.open(glossary_source_expand_path, "w") {|f| f << YAML.dump([]) }
      # and clear db too
      glossary.index!
    end

    describe '#add' do
      context 'with arguments show new bilingual pair' do
        before do
          glossary.add("spec", "スペック", "テストスペック")
        end

        it 'glossary yaml should have that bilingual pair' do
          yaml = YAML::load_file(glossary_source_expand_path)
          term = yaml.index({"source_term"=>"spec", "target_term"=>"スペック", "note"=>"テストスペック"})
          term.should_not be_nil
        end
      end

      context "when the glossary not found" do
        before do
          glossary.add("test", "テスト", "テスト")
        end

        it "should create the glossary and add term" do
          yaml = YAML::load_file(glossary_source_expand_path)
          term = yaml.index({"source_term"=>"test", "target_term"=>"テスト", "note"=>"テスト"})
          term.should_not be_nil
        end
      end
    end

    describe '#update' do
      before do
        glossary.add("user", "ユーザ", "ユーザーではない")
      end

      context 'with new-terget-term show existing bilingual pair' do
        it {
          -> { glossary.update("user", "ユーザー", "ユーザ", "やっぱりユーザー") }.should raise_error(Logaling::TermError)
        }
      end

      context 'with source-term show not existing bilingual pair' do
        it {
          -> { glossary.update("use", "ユーザ", "ユーザー", "やっぱりユーザー") }.should raise_error(Logaling::TermError)
        }
      end

      context 'with target-term show not existing bilingual pair' do
        it {
          -> { glossary.update("user", "ユー", "ユーザー", "やっぱりユーザー") }.should raise_error(Logaling::TermError)
        }
      end

      context 'with same target-term and empty note' do
        before do
          glossary.update("user", "ユーザ", "ユーザ", "")
        end

        it 'should clear note' do
          yaml = YAML::load_file(glossary_source_expand_path)
          term = yaml.index({"source_term"=>"user", "target_term"=>"ユーザ", "note"=>""})
          term.should_not be_nil
        end
      end

      context 'same [source-term, taget-term] pair can not exist' do
        before do
          glossary.add("user", "ゆーざー", "")
        end

        it {
          -> { glossary.update("user", "ゆーざ", "ユーザ", "") }.should raise_error(Logaling::TermError)
        }
      end
    end

    describe '#delete' do
      context 'bilingual pair exists' do
        before do
          glossary.add("delete_logaling", "てすと1", "備考")
          glossary.add("delete_logaling", "てすと2", "備考")
          glossary.delete("delete_logaling", "てすと1")
          @result = repository.lookup("delete_logaling", glossary)
        end

        it 'should delete the bilingual pair' do
          @result.any?{|term| term[:source_term] == "delete_logaling" && term[:target_term] == "てすと2"}.should be_true
          @result.any?{|term| term[:source_term] == "delete_logaling" && term[:target_term] == "てすと1"}.should be_false
        end
      end

      context 'bilingual pair does not exist' do
        before do
          glossary.add("user_logaling", "ユーザ", "ユーザーではない")
        end

        it {
          -> { glossary.delete("user_logaling", "ユーザー") }.should raise_error(Logaling::TermError)
        }
      end
    end

    describe '#delete_all' do
      context 'source_term not found' do
        before do
          glossary.add("user_logaling", "ユーザ", "備考")
        end

        it {
          -> { glossary.delete_all("usr_logaling") }.should raise_error(Logaling::TermError)
        }
      end

      context 'source_term found' do
        context 'there is only 1 bilingual pair' do
          before do
            glossary.add("user_logaling", "ユーザ", "備考")
            glossary.delete_all("user_logaling")
            @result = repository.lookup("user_logaling", glossary)
          end

          it 'should delete the term' do
            @result.any?{|term| term[:source_term] == "user_logaling" && term[:target_term] == "ユーザ"}.should be_false
          end
        end

        context 'there are more than 1 bilingual pair' do
          before do
            glossary.add("user_logaling", "ユーザ1", "備考")
            glossary.add("user_logaling", "ユーザ2", "備考")
            glossary.add("delete_logaling", "てすと1", "備考")
            glossary.add("delete_logaling", "てすと2", "備考")
            glossary.delete_all("delete_logaling", true)
            @result = Logaling::GlossarySource.create(glossary_source_path, glossary).load
          end

          it {
            -> { glossary.delete_all("user_logaling") }.should raise_error(Logaling::TermError)
          }

          it "should delete terms when force option is true" do
            @result.any?{|term| term == {"source_term"=>"delete_logaling", "target_term"=>"てすと1", "note"=>"備考"}}.should be_false
            @result.any?{|term| term == {"source_term"=>"delete_logaling", "target_term"=>"てすと2", "note"=>"備考"}}.should be_false
            @result.any?{|term| term == {"source_term"=>"user_logaling", "target_term"=>"ユーザ1", "note"=>"備考"}}.should be_true
            @result.any?{|term| term == {"source_term"=>"user_logaling", "target_term"=>"ユーザ2", "note"=>"備考"}}.should be_true
          end
        end
      end
    end

    after do
      FileUtils.rm_rf(File.join(logaling_home, 'projects', 'spec'), :secure => true)
    end
  end
end
