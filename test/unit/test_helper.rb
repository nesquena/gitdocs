# -*- encoding : utf-8 -*-

require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'gitdocs'
require 'mocha/setup'
Dir.glob(File.expand_path('../../support/**/*.rb', __FILE__)).each do |filename|
  require_relative filename
end

Gitdocs::Initializer.root_dirname = '/tmp/gitdocs'
Gitdocs::Initializer.database     = ':memory:'

require 'coveralls'
Coveralls.wear!

GitFactory.working_directory = File.expand_path('../../../tmp/unit', __FILE__)
