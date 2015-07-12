# -*- encoding : utf-8 -*-

require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'gitdocs'
require 'mocha/setup'

Gitdocs::Initializer.root_dirname = '/tmp/gitdocs'
Gitdocs::Initializer.database     = ':memory:'

require 'coveralls'
Coveralls.wear!
