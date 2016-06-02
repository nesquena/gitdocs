# -*- encoding : utf-8 -*-

require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'mocha/setup'
require 'shell_tools'
Dir.glob(File.expand_path('../../support/**/*.rb', __FILE__)).each do |filename|
  require_relative filename
end

# Setup code coverage, first ###################################################
require 'codeclimate-test-reporter'
SimpleCov.add_filter 'test'
SimpleCov.start
CodeClimate::TestReporter.start

# Load and configure the real code #############################################
require 'gitdocs'

Gitdocs::Initializer.root_dirname = '/tmp/gitdocs'
Gitdocs::Initializer.database     = ':memory:'

GitFactory.working_directory = File.expand_path('../../../tmp/unit', __FILE__)
