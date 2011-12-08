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
      before do
        FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
      end

      context "and call without option" do
        before do
          command.options = base_options.merge("glossary" => nil)
          @stdout = capture(:stdout) {command.unregister}
        end

        it "should print message 'input glossary name ...'" do
          @stdout.should be_include "input glossary name"
        end
      end

      context "and call with option" do
        before do
          command.new('spec', 'en', 'ja')
          @stdout = capture(:stdout) {command.unregister}
        end
        it 'should unregister symlink' do
          Dir[File.join(LOGALING_HOME, "projects", "*")].size.should == @project_counts
        end
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
        @stdout.should include "spec : スペック # 備考"
      end
    end

    context 'only one project exist in LOGALING_HOME/projects' do
      before do
        Dir.should_receive(:entries).with(File.join(LOGALING_HOME, "projects")).and_return([".", "..", "spec"])
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'should not show glossary name' do
        @stdout.should_not include "(spec)"
      end
    end

    context 'some projects exist in LOGALING_HOME/projects' do
      before do
        Dir.should_receive(:entries).with(File.join(LOGALING_HOME, "projects")).and_return([".", "..", "spec", "spec2"])
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'should show glossary name' do
        @stdout.should include "(spec)"
      end
    end
  end

  describe "#delete" do
    before do
      command.new('spec', 'en', 'ja')
      command.add('spec', 'スペック', '備考')
      command.add('user', 'ユーザ', '備考')
      command.add('test', 'てすと1', '備考')
      command.add('test', 'てすと2', '備考')
    end

    context 'with arguments exist term' do
      before do
        command.delete('spec', 'スペック')
        @stdout = capture(:stdout) {command.lookup("spec")}
      end

      it 'should delete the term' do
        @stdout.should_not include "spec : スペック # 備考"
      end
    end

    context 'without target_term' do
      context 'only 1 bilingual pair exist' do
      before do
        command.delete('user')
        @stdout = capture(:stdout) {command.lookup("user")}
      end

      it 'should delete the term' do
        @stdout.should_not include "user : ユーザ # 備考"
      end
      end

      context 'some bilingual pair exist' do
        context "called without '--force=true'" do
          before do
            @stdout = capture(:stdout) {command.delete('test')}
          end

          it "should print usage" do
            @stdout.should == "There are duplicate terms in glossary.\n" +
            "If you really want to delete, please put `loga delete [SOURCE_TERM] --force`\n" +
            " or `loga delete [SOURCE_TERM] [TARGET_TERM]`\n"
          end
        end

        context "and called with '--force=true'" do
          before do
            command.options = base_options.merge("force" => true)
            command.new('spec', 'en', 'ja')
            command.add('term', '用語1', '備考')
            command.add('term', '用語2', '備考')
            command.delete("term")
            @stdout = capture(:stdout) {command.lookup("term")}
          end

          it 'should delete bilingual pairs' do
            @stdout.should_not include "term : 用語1 # 備考"
            @stdout.should_not include "term : 用語2 # 備考"
          end
        end
      end
    end
  end

  after do
    FileUtils.remove_entry_secure(Logaling::Command::LOGALING_CONFIG, true)
    FileUtils.remove_entry_secure(File.join(LOGALING_HOME, 'projects', 'spec'), true)
  end
end
