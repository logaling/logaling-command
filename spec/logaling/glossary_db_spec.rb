# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Miho SUZUKI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require File.join(File.dirname(__FILE__), "..", "spec_helper")
#require "fileutils"

module Logaling
  describe Project do
    let(:logaling_home) { @logaling_home }
    let(:logaling_db_home) { File.join(@logaling_home, 'db') }
    let(:logaling_config) { File.join(File.dirname(__FILE__), "..", "tmp", ".logaling") }
    let(:base_options) { {"glossary"=>"spec", "source-language"=>"en", "target-language"=>"ja", "logaling-config" => logaling_config} }
    let(:command) { Logaling::Command::Application.new([], base_options) }
    let(:project_path) { File.join(logaling_home, 'projects') }
    let(:cache_path) { File.join(logaling_home, 'cache') }
    let(:personal_path) { File.join(logaling_home, 'personal') }

    before do
      FileUtils.rm_rf(File.join(project_path, 'spec'))
      FileUtils.mkdir_p(cache_path)
    end

    describe "#get_all_glossary_sources" do
      before do
        command.new('spec', 'en', 'fr')
        command.add('spec', 'スペック')
        command.copy('spec', 'en', 'fr', 'spec', 'en', 'ja')
        csv_path = File.join(cache_path, 'imported_spec.en.ja.csv')
        FileUtils.touch(csv_path)
        File.open(csv_path, "w"){|f| f.puts "test_logaling,テストろがりん"}
        command.index

        Logaling::GlossaryDB.open(logaling_db_home, "utf8") do |db|
          db.recreate_table
          @glossary_sources = db.get_all_glossary_sources
        end
      end

      it "should be set project correctly" do
        methods = ['personal?', 'normal_project?', 'imported?']
        methods.each do |method|
          project_get = nil
          @glossary_sources.each do |glossary_source|
            if glossary_source.glossary.project.send(method)
              project_get = glossary_source.glossary.project
            end
          end
          project_get.should_not be nil
        end
      end
    end

    after do
      FileUtils.rm_rf(File.join(project_path, 'spec'))
      FileUtils.rm_rf(cache_path)
      FileUtils.rm_rf(personal_path)
      FileUtils.rm_rf(logaling_config)
    end
  end
end
