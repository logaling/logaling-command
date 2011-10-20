# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logaling-command/version"

Gem::Specification.new do |s|
  s.name        = "logaling-command"
  s.version     = Logaling::Command::VERSION
  s.authors     = ["SHIMADA Koji"]
  s.email       = ["koji.shimada@enishi-tech.com"]
  s.homepage    = ""
  s.summary     = %q{A command line interface for logaling.}
  s.description = %q{A command line interface for logaling.}

  s.rubyforge_project = "logaling-command"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end
