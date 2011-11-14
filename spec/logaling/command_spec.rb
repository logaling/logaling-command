# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:command) { Logaling::Command.new }
  let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja"} }
  let(:glossary_path) { File.join(LOGALING_HOME, "/spec.en.ja.yml") }

  before do
    FileUtils.remove_file(glossary_path, true)
  end

  describe '#create' do
    context 'with options show non-existent glossary' do
      before do
        command.options = base_options
        command.create
      end

      it "glossary yaml should be newly created" do
        File.exists?(glossary_path).should be_true
      end
    end
  end

  describe "#update" do
    before do
      command.options = base_options
      command.create

      command.options = base_options.merge("source-term"=>"spec", "target-term"=>"テスト", "note"=>"備考")
      command.add
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

    context "not given note option" do
      before do
        command.options = base_options.merge("source-term"=>"spec", "target-term"=>"テスト", "new-target-term"=>"スペック")
        command.update
      end

      subject { YAML::load_file(glossary_path).find{|h| h["source-term"] == "spec" }}

      it "term's target-term should be updated" do
        subject["target-term"].should == "スペック"
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
