# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::GlossaryDB do
  let(:glossary_path) { Logaling::Glossary.build_path('spec', 'en', 'ja') }
  let(:tsv_path) { File.join(File.dirname(glossary_path), 'spec.en.ja.tsv') }
  let(:csv_path) { File.join(File.dirname(glossary_path), 'spec.en.ja.csv') }
  let(:glossary_db) { Logaling::GlossaryDB.new }

  before do
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
    FileUtils.mkdir_p(File.dirname(glossary_path))
  end

  describe '#get_file_list' do
    context 'when specified file not exist' do
      subject { glossary_db.get_file_list(File.dirname(glossary_path), ['yml', 'csv', 'tsv']) }
      it 'should return empty array' do
        should == []
      end
    end

    context 'when specified file exists' do
      before do
        FileUtils.touch(glossary_path)
        FileUtils.touch(tsv_path)
        FileUtils.touch(csv_path)
      end

      subject { glossary_db.get_file_list(File.dirname(glossary_path), ['yml', 'csv', 'tsv']) }
      it 'should return file list' do
        should == [glossary_path, csv_path, tsv_path]
      end

      after do
        FileUtils.remove_entry_secure(glossary_path, true)
        FileUtils.remove_entry_secure(tsv_path, true)
        FileUtils.remove_entry_secure(csv_path, true)
      end
    end
  end

  describe '#load_glossary' do
    context 'with argument yml' do
      before do
        FileUtils.touch(glossary_path)
        term = [{'source_term' => 'spec', 'target_term' => 'スペック', 'note' => 'スペック'}]
        File.open(glossary_path, "w"){|f| f.puts(term.to_yaml)}
      end

      subject { glossary_db.load_glossary(glossary_path) }

      it 'should return formatted glossary' do
        should == [{'source_term' => 'spec', 'target_term' => 'スペック', 'note' => 'スペック'}]
      end

      after do
        FileUtils.remove_entry_secure(glossary_path, true)
      end
    end

    context 'with argument tsv' do
      before do
        FileUtils.touch(tsv_path)
        term = "spec\tスペック"
        File.open(tsv_path, "w"){|f| f.puts(term)}
      end

      subject { glossary_db.load_glossary(tsv_path) }

      it 'should return formatted glossary' do
        should == [{'source_term' => 'spec', 'target_term' => 'スペック', 'note' => ''}]
      end

      after do
        FileUtils.remove_entry_secure(tsv_path, true)
      end
    end

    context 'with argument csv' do
      before do
        FileUtils.touch(csv_path)
        term = "spec,スペック,備考\ntest\n"
        File.open(csv_path, "w"){|f| f.puts(term)}
      end

      subject { glossary_db.load_glossary(csv_path) }

      it 'should return formatted glossary' do
        should == [{'source_term' => 'spec', 'target_term' => 'スペック', 'note' => ''}]
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

