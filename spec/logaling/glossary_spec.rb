# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")
require "fileutils"

module Logaling
  describe Glossary do
    let(:glossary) { Glossary.new('spec', 'en', 'ja', Dir.pwd) }
    let(:glossary_path) { File.join(Dir.pwd, 'spec.en.ja.yml') }

    describe '#add' do
      before do
        FileUtils.remove_file(glossary_path, true)
        glossary.create
      end

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

        subject{ capture(:stdout){ glossary.add("user", "ユーザ", "ユーザーではない") }}

        it 'stdout should receive error message' do
          should eq "[user] [ユーザ] pair already exists\n"
        end
      end

      after do
        FileUtils.remove_file(glossary_path, true)
      end
    end
  end
end
