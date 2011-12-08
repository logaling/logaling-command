# -*- coding: utf-8 -*-
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

      context 'with arguments show existing bilingual pair' do
        before do
          glossary.add("user", "ユーザ", "ユーザーではない")
        end

        it {
          -> { glossary.add("user", "ユーザ", "ユーザーではない") }.should raise_error(Logaling::TermError)
        }
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
    end

    describe '#delete' do
      context 'bilingual pair exists' do
        before do
          glossary.add("delete", "てすと1", "備考")
          glossary.add("delete", "てすと2", "備考")
          glossary.delete("delete", "てすと1")
          repository.index
          @result = repository.lookup("delete", "en", "ja", project)
        end

        it 'should delete the bilingual pair' do
          @result.should include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"delete", :target_term=>"てすと2", :note=>"備考"})
          @result.should_not include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"delete", :target_term=>"てすと1", :note=>"備考"})
        end
      end

      context 'bilingual pair does not exist' do
        before do
          glossary.add("user", "ユーザ", "ユーザーではない")
        end

        it {
          -> { glossary.delete("user", "ユーザー") }.should raise_error(Logaling::TermError)
        }
      end
    end

    describe '#delete_all' do
      context 'source_term not found' do
        before do
          glossary.add("user", "ユーザ", "備考")
        end

        it {
          -> { glossary.delete_all("usr") }.should raise_error(Logaling::TermError)
        }
      end

      context 'source_term found' do
        context 'there is only 1 bilingual pair' do
          before do
            glossary.add("user", "ユーザ", "備考")
            glossary.delete_all("user")
            repository.index
            @result = repository.lookup("user", "en", "ja", project)
          end

          it 'should delete the term' do
            @result.should_not include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザ", :note=>"備考"})
          end
        end

        context 'there are more than 1 bilingual pair' do
          before do
            glossary.add("user", "ユーザ1", "備考")
            glossary.add("user", "ユーザ2", "備考")
            glossary.add("delete", "てすと1", "備考")
            glossary.add("delete", "てすと2", "備考")
            glossary.delete_all("delete", true)
            repository.index
            @result = repository.lookup("delete", "en", "ja", project)
          end

          it {
            -> { glossary.delete_all("user") }.should raise_error(Logaling::TermError)
          }

          it "should delete terms when force option is true" do
            @result.should_not include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"delete", :target_term=>"てすと1", :note=>"備考"})
            @result.should_not include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"delete", :target_term=>"てすと2", :note=>"備考"})
          end
        end
      end
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
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザー", :note=>''})
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
          glossary.add("spec", "スペック", "備考")
          repository.index
        end

        subject { logaling_db.open(db_home, "utf8"){|db| logaling_db.lookup("spec")} }

        it 'glossaries should be indexed' do
          should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"spec", :target_term=>"スペック", :note=>"備考"})
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
          should == [{:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"user", :target_term=>"ユーザ", :note=>''}]
        end

        after do
          FileUtils.remove_entry_secure(tsv_path, true)
        end
      end

      context 'when csv file as glosary exists' do
        before do
          FileUtils.mkdir_p(File.dirname(glossary_path))
          FileUtils.touch(csv_path)
          File.open(csv_path, "w"){|f| f.puts "test,テスト"}
          repository.index
        end

        subject { logaling_db.open(db_home, "utf8"){|db| logaling_db.lookup("test")} }

        it 'glossaries should be indexed' do
          should == [{:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"test", :target_term=>"テスト", :note=>''}]
        end

        after do
          FileUtils.remove_entry_secure(csv_path, true)
        end
      end
    end

    after do
      FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
    end
  end
end
