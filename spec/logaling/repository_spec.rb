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
    let(:glossary) { Glossary.new(project, 'en', 'ja') }
    let(:glossary_path) { Glossary.build_path(project, 'en', 'ja') }
    let(:repository) { Logaling::Repository.new(LOGALING_HOME) }

    before do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
      FileUtils.mkdir_p(File.dirname(glossary_path))
    end

    describe '#lookup' do
      before do
        glossary.add("user", "ユーザ", "ユーザーではない")
        repository.index
      end

      context 'with arguments show existing bilingual pair' do
        subject {repository.lookup("user", "en", "ja", project)}

        it 'succeed at find by term' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザ", :note=>"ユーザーではない"})
        end
      end

      context 'when tsv file as glossary exists' do
        let(:tsv_path) { glossary_path.sub(/yml$/, 'tsv') }

        before do
          FileUtils.mkdir_p(File.dirname(tsv_path))
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "user\tユーザー"}
          repository.index
        end

        subject {repository.lookup("user", "en", "ja", project)}

        it 'succeed at find by term' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザー", :note=>""})
        end

        after do
          FileUtils.remove_entry_secure(tsv_path, true)
        end
      end
    end

    describe '#index' do
      let(:db_home) { File.join(LOGALING_HOME, "db") }
      let(:logaling_db) { Logaling::GlossaryDB.new }
      let(:tsv_path) { File.join(File.dirname(glossary_path), "spec.en.ja.tsv") }
      let(:csv_path) { File.join(File.dirname(glossary_path), "spec.en.ja.csv") }

      context 'when yml file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_path))
          FileUtils.touch(glossary_path)
          glossary.add("spec_logaling", "スペック", "備考")
          repository.index
        end

        subject { logaling_db.open(db_home, "utf8"){|db| logaling_db.lookup("spec_logaling")} }

        it 'glossaries should be indexed' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"spec_logaling", :target_term=>"スペック", :note=>"備考"})
        end

        after do
          FileUtils.remove_entry_secure(glossary_path, true)
        end
      end

      context 'when tsv file as glossary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_path))
          FileUtils.touch(tsv_path)
          File.open(tsv_path, "w"){|f| f.puts "user\tユーザ"}
          repository.index
        end

        subject { logaling_db.open(db_home, "utf8"){|db| logaling_db.lookup("user")} }

        it 'glossaries should be indexed' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザ", :note=>''})
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
        end

        subject { logaling_db.open(db_home, "utf8"){|db| logaling_db.lookup("test_logaling")} }

        it 'glossaries should be indexed' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"test_logaling", :target_term=>"テスト", :note=>""})
        end

        after do
          FileUtils.remove_entry_secure(csv_path, true)
        end
      end
    end

    context 'when glossary exist but not modified' do
      let(:index_at) { File.join(LOGALING_HOME, 'db', 'index_at') }
      before do
        glossary.add("index_test", "インデックスのテスト", "備考")
        repository.index
        @timestamp = File.mtime(index_at)
        sleep(1)
        repository.index
      end

      subject { File.mtime(index_at) }

      it 'should not be indexed' do
        should == @timestamp
      end
    end

    after do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
    end
  end
end
