require 'bundler/gem_tasks'
require 'rake/testtask'
require 'jslint/tasks'

JSLint.config_path = '.jslint.yml'

namespace :test do
  # Separate the unit and integration tests when running the entire suite.
  Rake::TestTask.new(:unit) do |t|
    t.libs.push('lib')
    t.test_files = FileList[File.expand_path('../test/unit/**/*_test.rb', __FILE__)]
    t.verbose = true
  end

  Rake::TestTask.new(integration: :unit) do |t|
    t.libs.push('lib')
    t.test_files = FileList[File.expand_path('../test/integration/**/*_test.rb', __FILE__)]
    t.verbose = true
  end
end

# Keep a default test task for manually running any test
Rake::TestTask.new do |t|
  t.libs.push('lib')
  t.test_files = FileList[File.expand_path('../test/**/*_test.rb', __FILE__)]
  t.verbose = true
end

task default: 'test:integration'
