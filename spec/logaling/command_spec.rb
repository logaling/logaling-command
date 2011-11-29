# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja"} }
  let(:command) { Logaling::Command.new([], base_options) }
  let(:glossary_path) { Logaling::Glossary.build_path('spec', 'en', 'ja') }
  let(:target_project_path) { File.join(LOGALING_HOME, "projects", "spec") }

  before do
    FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end

  describe '#new' do
    before do
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context 'when .logaling already exists' do
      before do
        FileUtils.mkdir_p(Logaling::Command::LOGALING_CONFIG)
        @stdout = capture(:stdout) { command.new('spec', 'en', 'ja') }
      end

      it 'print message \"<.logaling path> already exists.\"' do
        @stdout.should == "#{Logaling::Command::LOGALING_CONFIG} already exists.\n"
      end
    end

    context 'when .logaling does not exist' do
      context 'and called with no special option' do
        before do
          command.new('spec', 'en', 'ja')
        end

        it 'should create .logaling' do
          File.exist?(Logaling::Command::LOGALING_CONFIG).should be_true
        end

        it 'should register .logaling as project' do
          File.exist?(target_project_path).should be_true
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts + 1
        end
      end

      context "and called with '--no-register=true'" do
        before do
          command.options = base_options.merge("no-register" => true)
          command.new('spec', 'en', 'ja')
        end

        it 'should create .logaling' do
          File.exist?(Logaling::Command::LOGALING_CONFIG).should be_true
        end

        it 'should not register .logaling as project' do
          File.exist?(target_project_path).should be_false
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
      end
    end
  end

  describe '#register' do
    before do
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context "when can not find .logaling" do
      before(:all) do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
        @stdout = capture(:stdout) {command.register}
      end

      it 'register nothing' do
        Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
      end

      it "print message \"Try 'loga new' first.\"" do
        @stdout.should be_include "Try 'loga new' first.\n"
      end
    end

    context 'when find .logaling' do
      before do
        command.new('spec', 'en', 'ja')
        command.register
      end

      it 'register .logaling as project' do
        File.exist?(target_project_path).should be_true
        Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts + 1
      end

      after do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
      end
    end
  end

  describe '#unregister' do
    before do
      @project_counts = Dir[File.join(LOGALING_HOME, "projects", "*")].size
    end

    context "when can not find .logaling" do
      before(:all) do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
        @stdout = capture(:stdout) {command.unregister}
      end

      it 'unregister nothing' do
        Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
      end

      it "print message \"Can't found .logaling in [...]\"" do
        @stdout.should be_include "Can't found .logaling in"
      end
    end

    context 'when find .logaling' do
      context 'and .logaling registered' do
        before do
          command.new('spec', 'en', 'ja')
          command.register
          command.unregister
        end

        it 'unregister .logaling' do
          File.exist?(target_project_path).should be_false
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
      end

      context "and .logaling is not registered" do
        before do
          command.options = base_options.merge("no-register" => true)
          command.new('spec', 'en', 'ja')
          @stdout = capture(:stdout) {command.unregister}
        end

        it "print message \"<glossary name> is not yet registered.\"" do
          @stdout.should == "spec is not yet registered.\n"
        end
      end
    end
  end

  describe '#create' do
    context 'with arguments show non-existent glossary' do
      before do
        command.new('spec', 'en', 'ja')
        command.register
        command.create
      end

      it "glossary yaml should be newly created" do
        File.exists?(glossary_path).should be_true
      end
    end
  end

  describe '#add' do
    before do
      command.new('spec', 'en', 'ja')
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
      command.new('spec', 'en', 'ja')
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
      command.new('spec', 'en', 'ja')
      command.add("spec", "スペック", "備考")
      command.index
    end

    context 'glossary files exist in some project' do
      subject do
        db_home = File.join(LOGALING_HOME, "db")
        Logaling::GlossaryDB.open(db_home, "utf8"){|db| records = db.lookup("spec")}
      end

      it 'glossaries should be indexed' do
        should be_include({:name=>"spec", :source_language=>"en", :target_language=>"ja", :source_term=>"spec", :target_term=>"スペック", :note=>"備考"})
      end
    end
  end

  describe '#lookup' do
    before do
      command.new('spec', 'en', 'ja')
      command.add("spec", "スペック", "備考")
    end

    context 'with arguments exist term' do
      before do
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'succeed at find by term without command.index' do
        @stdout.should be_include "glossary:spec"
      end
    end
  end

  after do
    FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end
end
