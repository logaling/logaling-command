# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logaling/command"

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

  s.add_runtime_dependency 'thor', ['>= 0.14.6']
  s.add_runtime_dependency 'bundler', ['>= 1.0']
  s.add_runtime_dependency 'rroonga', ['>= 1.3.0']
  s.add_runtime_dependency 'rainbow'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end
