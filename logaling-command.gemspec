# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "logaling-command/version"

Gem::Specification.new do |s|
  s.name        = "logaling-command"
  s.version     = Logaling::Command::VERSION
  s.authors     = ["SHIMADA Koji"]
  s.email       = ["snoozer.05@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "logaling-command"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
