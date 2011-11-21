# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja"} }
  let(:command) { Logaling::Command.new([], base_options) }
  let(:project) { "spec" }
  let(:glossary_path) { Logaling::Glossary.build_path(project, 'en', 'ja') }

  before do
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end

  describe '#create' do
    before do
      FileUtils.mkdir_p(File.dirname(glossary_path))
      FileUtils.touch(glossary_path)
    end

    context 'with arguments show non-existent glossary' do
      it "glossary yaml should be newly created" do
        File.exists?(glossary_path).should be_true
      end
    end
  end

  describe '#add' do
    context 'with arguments have only bilingual pair' do
      before do
        FileUtils.mkdir_p(File.dirname(glossary_path))
        command.add("spec", "テスト")
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }}

      it "glossary yaml should contain that term" do
        subject["target_term"].should == "テスト"
      end

      it "term should note have note" do
        subject["note"].should == ""
      end
    end

    context 'with arguments have bilingual pair and note' do
      before do
        FileUtils.mkdir_p(File.dirname(glossary_path))
        command.add("spec", "テスト", "備考")
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }}

      it "glossary yaml should contain that term" do
        subject["target_term"].should == "テスト"
      end

      it "term should have note" do
        subject["note"].should == "備考"
      end
    end
  end

  describe "#update" do
    before do
      FileUtils.mkdir_p(File.dirname(glossary_path))
      command.add("spec", "テスト", "備考")
    end

    context "not given source-term option" do
      # should show err
    end

    context "not given target-term option" do
      #should show err
    end

    context "not given new-target-term option" do
      #should show err
    end

    context "with arguments except note" do
      before do
        command.update("spec", "テスト", "スペック")
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source_term"] == "spec" }}

      it "term's target_term should be updated" do
        subject["target_term"].should == "スペック"
      end

      it "term's note should not be updated" do
        subject["note"].should == "備考"
      end
    end
  end

  describe '#index' do
    before do
      FileUtils.mkdir_p(File.dirname(glossary_path))
      command.add("spec", "スペック", "備考")
      command.index
    end

    context 'glossary files exist in some project' do
      db_home = File.join(LOGALING_HOME, "db")
      db = Logaling::GlossaryDB.new

      subject { db.open(db_home, "utf8"){|db| records = db.lookup("spec")} }

      it 'glossaries should be indexed' do
        subject.should == [{:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"spec", :target_term=>"スペック", :note=>"備考"}]
      end
    end
  end

  describe '#lookup' do
    let(:base_options2) { {"glossary"=>"spec2", "source-language"=>"en", "target-language"=>"ja"} }
    let(:command2) { Logaling::Command.new([], base_options2) }
    let(:project2) { "spec2" }
    let(:glossary_path2) { Logaling::Glossary.build_path(project2, 'en', 'ja') }

    context 'with arguments exist term' do
      before do
        FileUtils.mkdir_p(File.dirname(glossary_path))
        command.add("spec", "スペック", "備考")
        FileUtils.mkdir_p(File.dirname(glossary_path2))
        command2.add("spec", "スペック")
      end

      it 'succeed at find by term without command.index' do
        stdout = capture(:stdout) {command.lookup("spec")}
        stdout.should == <<-EOM

lookup word : spec

  spec
  スペック
    note:備考
    glossary:spec

  spec
  スペック
    note:
    glossary:spec2
        EOM
      end

      after do
        FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec2'), true)
      end
    end
  end

  after do
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end
end
