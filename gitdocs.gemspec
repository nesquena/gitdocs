# -*- encoding: utf-8 -*-
$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'gitdocs/version'

Gem::Specification.new do |s|
  s.name        = 'gitdocs'
  s.version     = Gitdocs::VERSION
  s.authors     = ['Josh Hull', 'Nathan Esquenazi']
  s.email       = ['joshbuddy@gmail.com', 'nesquena@gmail.com']
  s.homepage    = 'https://github.com/nesquena/gitdocs'

  s.summary     = 'Open-source Dropbox using Ruby and Git.'
  s.description = 'Open-source Dropbox using Ruby and Git.'
  s.license     = 'MIT'

  s.rubyforge_project = 'gitdocs'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 1.9'

  s.add_dependency 'joshbuddy-guard', '~> 0.10.0'
  s.add_dependency 'thin',            '~> 1.6.2'
  s.add_dependency 'sinatra',         '~> 1.4.5'
  s.add_dependency 'redcarpet',       '~> 3.2.2'
  s.add_dependency 'thor',            '~> 0.14.6'
  s.add_dependency 'coderay',         '~> 1.1.0'
  s.add_dependency 'dante',           '~> 0.1.2'
  s.add_dependency 'growl',           '~> 1.0.3'
  s.add_dependency 'haml',            '~> 4.0.5'
  s.add_dependency 'sqlite3',         '~> 1.3.4'
  s.add_dependency 'activerecord',    '~> 4.2.0'
  s.add_dependency 'grit',            '~> 2.5.0'
  s.add_dependency 'shell_tools',     '~> 0.1.0'
  s.add_dependency 'mimetype-fu',     '~> 0.1.2'
  s.add_dependency 'eventmachine',    '>= 1.0.3'
  s.add_dependency 'launchy',         '~> 2.4.2'
  s.add_dependency 'rugged',          '~> 0.19.0'
  s.add_dependency 'table_print',     '~> 1.5.1'

  s.add_development_dependency 'minitest',               '~> 5.5.0'
  s.add_development_dependency 'capybara_minitest_spec', '~> 1.0.2'
  s.add_development_dependency 'poltergeist',            '~> 1.5.1'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'mocha'
  s.add_development_dependency 'fakeweb'
  s.add_development_dependency 'metric_fu'
  s.add_development_dependency 'aruba'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'haml-lint',              '~> 0.10.0'
  s.add_development_dependency 'jslint_on_rails',        '~> 1.1.1'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'shotgun'
end
