# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe Logaling::Command do
  let(:command) { Logaling::Command.new }

  describe '#create' do
    context 'with arguments show non-existent glossary' do
      let(:glossary_path) { File.join(LOGALING_HOME, "/spec.en.ja.yml") }

      before do
        FileUtils.remove_file(glossary_path, true)

        command.options = {"glossary"=>"spec","source_language"=>"en","target_language"=>"ja"}
        command.create
      end

      it "glossary yaml should be newly created" do
        File.exists?(glossary_path).should be_true
      end

      after do
        FileUtils.remove_file(glossary_path, true)
      end
    end
  end
end
