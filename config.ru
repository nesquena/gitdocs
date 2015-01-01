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

config_root = './tmp/web'
FileUtils.mkdir_p(config_root)
Gitdocs::SettingsApp.set :manager, Gitdocs::Manager.new(config_root, true)
Gitdocs::SettingsApp.set :logging, true
map('/settings') { run Gitdocs::SettingsApp }

Gitdocs::BrowserApp.set :repositories, Gitdocs::Configuration.new(config_root).shares.map { |x| Gitdocs::Repository.new(x) }
Gitdocs::BrowserApp.set :logging, true
map('/') { run Gitdocs::BrowserApp }
