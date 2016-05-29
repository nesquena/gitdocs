require 'bundler/gem_tasks'
require 'rake/testtask'
require 'jslint/tasks'
require 'haml_lint/rake_task'
require 'rubocop/rake_task'

JSLint.config_path = '.jslint.yml'

HamlLint::RakeTask.new

RuboCop::RakeTask.new

namespace :test do
  # Separate the unit and integration tests when running the entire suite.
  Rake::TestTask.new(:unit) do |t|
    t.libs.push('lib')
    t.test_files = FileList[File.expand_path('../test/unit/**/*_test.rb', __FILE__)]
    t.verbose = true
  end

  namespace :integration do
    Rake::TestTask.new(cli: 'test:unit') do |t|
      t.libs.push('lib')
      t.test_files = FileList[File.expand_path('../test/integration/cli/**/*_test.rb', __FILE__)]
      t.verbose = true
    end

    Rake::TestTask.new(web: :cli) do |t|
      t.libs.push('lib')
      t.test_files = FileList[File.expand_path('../test/integration/web/**/*_test.rb', __FILE__)]
      t.verbose = true
    end
  end

  desc 'Run all integration tests'
  task integration: 'integration:web'
end

# Keep a default test task for manually running any test
Rake::TestTask.new do |t|
  t.libs.push('lib')
  t.test_files = FileList[File.expand_path('../test/**/*_test.rb', __FILE__)]
  t.verbose = true
end

desc 'Start the web interface for development'
task server: 'server:start'

namespace :server do
  task :start do
    sh('shotgun config.ru')
  end

  desc 'Copy the current configuration for use with the development web interface'
  task :copy_config do
    FileUtils.mkdir_p('./tmp/web')
    FileUtils.copy(
      File.expand_path('.gitdocs/config.db', ENV['HOME']),
      './tmp/web/config.db'
    )
  end
end

desc 'Run the daemon in debugging mode'
task :debug do
  exec('bin/gitdocs start --foreground --verbose --port 9999')
end

if ENV['TRAVIS']
  task default: 'test:integration:cli'
else
  task default: 'test:integration'
end
