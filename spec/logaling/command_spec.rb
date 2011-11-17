# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja"} }
  let(:command) { Logaling::Command.new([], base_options) }
  let(:project) { "spec" }
  let(:glossary_path) { Logaling::Glossary.build_path(project, 'en', 'ja') }

  before do
    FileUtils.remove_file(glossary_path, true)
  end

  describe '#create' do
    context 'with arguments show non-existent glossary' do
      before do
        command.create
      end

      it "glossary yaml should be newly created" do
        File.exists?(glossary_path).should be_true
      end
    end
  end

  describe '#add' do
    before do
      command.create
    end

    context 'with arguments have only bilingual pair' do
      before do
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
      command.create
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

  after do
    FileUtils.remove_file(glossary_path, true)
  end
end
