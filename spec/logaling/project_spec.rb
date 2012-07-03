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
require "fileutils"

module Logaling
  describe Project do
    let(:logaling_home) { @logaling_home }
    let(:repository) { Logaling::Repository.new(logaling_home) }
    let(:project_path) { File.join(logaling_home, 'projects', 'spec') }
    let(:project) { repository.find_project("spec") }

    before do
      FileUtils.remove_entry_secure(project_path, true)
      FileUtils.mkdir_p(File.join(project_path, "glossary"))
    end

    describe "#glossaries" do
      before do
        FileUtils.touch(File.join(project_path, "glossary", "spec.en.ja.yml"))
      end

      context "project has only 'en-ja' glossary" do
        it "should be include 'en-ja' glossary" do
          project.glossaries.map(&:to_s).should be_include "spec.en.ja"
        end
      end

      context "project has 'en-ja' 'fr-ja' glossaries" do
        before do
          FileUtils.touch(File.join(project_path, "glossary", "spec.fr.ja.yml"))
        end

        it "should be include 'en-ja' 'fr-ja' glossaries" do
          %w(spec.en.ja spec.fr.ja).each do |glossary_name|
            project.glossaries.map(&:to_s).should be_include glossary_name
          end
        end
      end

      context "project has two 'en-ja' glossary sources" do
        before do
          FileUtils.touch(File.join(project_path, "glossary", "spec.en.ja.csv"))
        end

        it "should count as one glossary" do
          project.glossaries.size.should == 1
        end
      end
    end
  end
end
