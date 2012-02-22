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
    let(:glossary) { Glossary.new(project, 'en', 'ja', logaling_home) }
    let(:glossary_path) { glossary.source_path }
    let(:repository) { Logaling::Repository.new(logaling_home) }
    let(:db_home) { File.join(logaling_home, "db") }

    before do
      FileUtils.remove_entry_secure(File.join(logaling_home, 'projects', 'spec'), true)
      FileUtils.mkdir_p(File.dirname(glossary_path))
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

      context 'when tsv file as glossary exists' do
        let(:tsv_path) { glossary_path.sub(/yml$/, 'tsv') }

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
      let(:tsv_path) { File.join(File.dirname(glossary_path), "spec.en.ja.tsv") }
      let(:csv_path) { File.join(File.dirname(glossary_path), "spec.en.ja.csv") }

      context 'when yml file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_path))
          FileUtils.touch(glossary_path)
          glossary.add("spec_logaling", "スペック", "備考")
          repository.index
          @terms = repository.lookup("spec_logaling", glossary)
        end

        it 'glossaries should be indexed' do
          @terms.size.should == 1
        end

        after do
          FileUtils.remove_entry_secure(glossary_path, true)
        end
      end

      context 'when tsv file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_path))
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
          FileUtils.mkdir_p(File.dirname(glossary_path))
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
