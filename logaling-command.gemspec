# -*- coding: utf-8 -*-
#
#    Copyright (C) 2011  Miho SUZUKI
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

$:.push File.expand_path("../lib", __FILE__)
require "logaling/command/version"

Gem::Specification.new do |s|
  s.name        = "logaling-command"
  s.version     = Logaling::Command::VERSION
  s.authors     = ["SHIMADA Koji", "SHIDARA Yoji", "Kouhei Sutou", "Daijiro MORI", "SUZUKI Miho"]
  s.email       = ["koji.shimada@enishi-tech.com", "dara@shidara.net", "kou@clear-code.com", "daijiro.mori@gmail.com", "adzuki34@gmail.com"]
  s.homepage    = "http://logaling.github.com/"
  s.summary     = %q{A command line interface for logaling.}
  s.description = %q{A command line interface for logaling.}

  s.rubyforge_project = "logaling-command"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 1.9.2'

  s.add_runtime_dependency 'thor', ['>= 0.14.6']
  s.add_runtime_dependency 'bundler', ['>= 1.0']
  s.add_runtime_dependency 'rroonga', ['>= 2.0.3']
  s.add_runtime_dependency 'rainbow'
  s.add_runtime_dependency 'nokogiri'
  s.add_runtime_dependency 'activesupport'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end
