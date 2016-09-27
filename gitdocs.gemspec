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

  # FIXME: celluloid v0.17 is not compatible with reel-rack/reel. It can only
  # be upgraded once that is resolved.
  s.add_dependency 'celluloid',       '~> 0.16.0'
  s.add_dependency 'reel-rack',       '~> 0.2.2'
  # NOTE: celluloid-io needs and explicit dependency because the dependency
  # from reel does not limit it to v0.16. Potentially this could be removed
  # once upgrade to the latest celluloid.
  s.add_dependency 'celluloid-io',    '~> 0.16.0'
  # FIXME: listen cannot be upgraded until we drop support for Ruby <v2.1
  s.add_dependency 'listen',          '~> 3.0.5'

  s.add_dependency 'sinatra',         '~> 1.4.5'
  s.add_dependency 'redcarpet',       '~> 3.3.0'
  s.add_dependency 'thor',            '~> 0.19.1'
  s.add_dependency 'coderay',         '~> 1.1.0'
  s.add_dependency 'dante',           '~> 0.2.0'
  s.add_dependency 'growl',           '~> 1.0.3'
  s.add_dependency 'haml',            '~> 4.0.5'
  # NOTE: Using tilt/redcarpet requires tilt v2, but the dependency from
  # sinatra only request 1.5. This is fine if tilt is being installed fresh,
  # but gitdocs will fail if you already have tilt between v1.5 and v2.0
  # installed.
  s.add_dependency 'tilt',            '>= 2.0.0'
  s.add_dependency 'sqlite3',         '~> 1.3.4'
  # NOTE: activerecord is not being updated to v5.x because this version drops
  # support for Ruby2.0. Ruby2.0 is EOLed but is still the default ruby version
  # installed on OSX.
  s.add_dependency 'activerecord',    '~> 4.2.0'
  s.add_dependency 'grit',            '~> 2.5.0'
  s.add_dependency 'mimetype-fu',     '~> 0.1.2'
  s.add_dependency 'launchy',         '~> 2.4.2'
  s.add_dependency 'rugged',          '~> 0.24.0'
  s.add_dependency 'table_print',     '~> 1.5.1'
  s.add_dependency 'notiffany',       '~> 0.1.0'

  s.add_development_dependency 'minitest',               '~> 5.9.0'
  s.add_development_dependency 'capybara_minitest_spec', '~> 1.0.2'
  s.add_development_dependency 'shell_tools',            '~> 0.1.0'
  s.add_development_dependency 'poltergeist',            '~> 1.7.0'
  s.add_development_dependency 'rake',                   '~> 11.3.0'
  s.add_development_dependency 'mocha',                  '~> 1.1.0'
  s.add_development_dependency 'aruba',                  '~> 0.6.1'
  s.add_development_dependency 'rubocop',                '~> 0.44.0'
  s.add_development_dependency 'haml_lint',              '~> 0.18.2'
  s.add_development_dependency 'jslint_on_rails',        '~> 1.1.1'
  s.add_development_dependency 'shotgun',                '~> 0.9.1'
  s.add_development_dependency 'codeclimate-test-reporter'
end
