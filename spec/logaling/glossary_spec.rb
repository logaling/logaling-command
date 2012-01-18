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
    let(:project) { "spec" }
    let(:glossary) { Glossary.new(project, 'en', 'ja') }
    let(:glossary_path) { Glossary.build_path(project, 'en', 'ja') }
    let(:repository) { Logaling::Repository.new(LOGALING_HOME) }

    before do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
      FileUtils.mkdir_p(File.dirname(glossary_path))
    end

    describe '#add' do
      context 'with arguments show new bilingual pair' do
        before do
          glossary.add("spec", "スペック", "テストスペック")
        end

        it 'glossary yaml should have that bilingual pair' do
          yaml = YAML::load_file(glossary_path)
          term = yaml.index({"source_term"=>"spec", "target_term"=>"スペック", "note"=>"テストスペック"})
          term.should_not be_nil
        end
      end

      context "when the glossary not found" do
        before do
          glossary.add("test", "テスト", "テスト")
        end

        it "should create the glossary and add term" do
          yaml = YAML::load_file(glossary_path)
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

      context 'with source-term arguments show not existing bilingual pair' do
        it {
          -> { glossary.update("use", "ユーザ", "ユーザー", "やっぱりユーザー") }.should raise_error(Logaling::TermError)
        }
      end

      context 'with target-term arguments show not existing bilingual pair' do
        it {
          -> { glossary.update("user", "ユー", "ユーザー", "やっぱりユーザー") }.should raise_error(Logaling::TermError)
        }
      end

      context 'with note arguments show exisiting bilingual pair' do
        it {
          -> { glossary.update("user", "ユーザ", "ユーザ", "") }.should raise_error(Logaling::TermError)
        }
      end
    end

    describe '#delete' do
      context 'bilingual pair exists' do
        before do
          glossary.add("delete_logaling", "てすと1", "備考")
          glossary.add("delete_logaling", "てすと2", "備考")
          glossary.delete("delete_logaling", "てすと1")
          repository.index
          @result = repository.lookup("delete_logaling", "en", "ja", project)
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
            repository.index
            @result = repository.lookup("user_logaling", "en", "ja", project)
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
            repository.index
            @result = repository.lookup("delete_logaling", "en", "ja", project)
          end

          it {
            -> { glossary.delete_all("user_logaling") }.should raise_error(Logaling::TermError)
          }

          it "should delete terms when force option is true" do
            @result.any?{|term| term[:source_term] == "delete_logaling" && term[:target_term] == "てすと1"}.should be_false
            @result.any?{|term| term[:source_term] == "delete_logaling" && term[:target_term] == "てすと2"}.should be_false
          end
        end
      end
    end

    after do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
    end
  end
end
