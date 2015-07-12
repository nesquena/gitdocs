require './lib/gitdocs'
require './lib/gitdocs/manager'
require './lib/gitdocs/settings_app'
require './lib/gitdocs/browser_app'
require './lib/gitdocs/repository'
require './lib/gitdocs/configuration'

use Rack::Static,
  urls: %w(/css /js /img /doc),
  root: './lib/gitdocs/public'
use Rack::MethodOverride

Gitdocs::Initializer.root_dirname = './tmp/web'
Gitdocs::Initializer.initialize_database

Gitdocs::SettingsApp.set :logging, true
map('/settings') { run Gitdocs::SettingsApp }

Gitdocs::BrowserApp.set :repositories, Gitdocs::Share.all.map { |x| Gitdocs::Repository.new(x) }
Gitdocs::BrowserApp.set :logging, true
map('/') { run Gitdocs::BrowserApp }
