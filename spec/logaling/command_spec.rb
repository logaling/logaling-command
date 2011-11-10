# -*- coding: utf-8 -*-
require File.join(File.dirname(__FILE__), "..", "spec_helper")


describe Logaling::Command do
  describe '#create' do
    context 'when same glossary not exists' do
      @command = Logaling::Command.new([], {"glossary"=>"spec","source_language"=>"en","target_language"=>"ja"})
      @command.create

      File.exists?(File.join(LOGALING_HOME, "/spec.en.ja.yml"))
      it { should be_true }
    end

  end

  after do
    path = File.join(LOGALING_HOME, "/spec.en.ja.yml")
    p path
    File.unlink(path) if File.exists?(path)
  end

end
