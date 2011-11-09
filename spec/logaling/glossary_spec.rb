# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")
require "fileutils"

module Logaling
  describe Glossary do
    before do
      @path = File.join(Dir.pwd(), 'spec.en.ja.yml')
      FileUtils.mkdir_p(Dir.pwd())
      FileUtils.touch(@path)
      @glossary = Glossary.new('spec', 'en', 'ja', Dir.pwd())
    end

    after do
      FileUtils.remove_file(@path, true)
    end

    describe '#add' do
      context 'when source_term and target_term pair not exists' do
        subject do
          @glossary.add("spec", "スペック", "テストスペック")
          yaml = YAML::load_file(@path)
          yaml.index({"source_term"=>"spec", "target_term"=>"スペック", "note"=>"テストスペック"})
        end
        it 'add source_term and target_term to specified glossary' do
          should_not be_nil
        end
      end

      context 'when source_term and target_term pair already exists' do
        before do
          File.open(@path, "w") do |f|
            f.puts([{"source_term" => "user", "target_term" => "ユーザ", "note" => "ユーザーではない"}].to_yaml)
          end
        end

        subject {capture(:stdout){ @glossary.add("user", "ユーザ", "ユーザーではない") }}
        it 'puts error message' do
          should eq "[user] [ユーザ] pair already exists\n"
        end
      end
    end
  end
end
