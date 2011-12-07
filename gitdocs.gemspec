# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gitdocs/version"

Gem::Specification.new do |s|
  s.name        = "gitdocs"
  s.version     = Gitdocs::VERSION
  s.authors     = ["Josh Hull", "Nathan Esquenazi"]
  s.email       = ["joshbuddy@gmail.com", "nesquena@gmail.com"]
  s.homepage    = "http://engineering.gomiso.com/2011/11/30/collaborate-and-track-tasks-with-ease-using-gitdocs/"
  s.summary     = %q{Open-source Dropbox using Ruby and Git}
  s.description = %q{Open-source Dropbox using Ruby and Git.}

  s.rubyforge_project = "gitdocs"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'rb-fsevent',   '~> 0.4.3.1'
  s.add_dependency 'thin'
  s.add_dependency 'renee', '~> 0.3.6'
  s.add_dependency 'redcarpet'
  s.add_dependency 'thor'
  s.add_dependency 'coderay'
  s.add_dependency 'dante', '~> 0.1.2'
  s.add_dependency 'growl', '~> 1.0.3'
  s.add_dependency 'yajl-ruby'
  s.add_dependency 'haml'
  s.add_dependency 'sqlite3', "~> 1.3.4"
  s.add_dependency 'activerecord', "~> 3.1.0"
  s.add_dependency 'grit', "~> 2.4.1"
  s.add_dependency 'shell_tools', "~> 0.1.0"

  s.add_development_dependency 'minitest', "~> 2.6.1"
  s.add_development_dependency 'rake'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'fakeweb'
end
