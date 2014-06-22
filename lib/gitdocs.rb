# -*- encoding : utf-8 -*-

require 'thread'
require 'yajl'
require 'dante'
require 'socket'
require 'shell_tools'
require 'guard'
require 'grit'
require 'rugged'
require 'table_print'

require 'gitdocs/version'
require 'gitdocs/configuration'
require 'gitdocs/runner'
require 'gitdocs/server'
require 'gitdocs/cli'
require 'gitdocs/manager'
require 'gitdocs/docfile'
require 'gitdocs/rendering'
require 'gitdocs/notifier'
require 'gitdocs/repository'
require 'gitdocs/search'

module Gitdocs
  DEBUG = ENV['DEBUG']

  # Gitdocs.start(:config_root => "...", :debug => true)
  def self.start(options = {}, &blk)
    options = { debug: DEBUG, config_root: nil }.merge(options)
    @manager.stop if @manager
    @manager = Manager.new(options[:config_root], options[:debug], &blk)
    @manager.start(options[:port])
  end

  def self.restart
    @manager.restart
  end

  def self.stop
    @manager.stop
  end
end
