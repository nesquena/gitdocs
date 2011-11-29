# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gitdocs/version"

Gem::Specification.new do |s|
  s.name        = "gitdocs"
  s.version     = Gitdocs::VERSION
  s.authors     = ["Josh Hull"]
  s.email       = ["joshbuddy@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{TODO: Write a gem summary}
  s.description = %q{TODO: Write a gem description}

  s.rubyforge_project = "gitdocs"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'rb-fsevent',   '~> 0.4.3.1'
  s.add_dependency 'growl_notify', '~> 0.0.3'
end
