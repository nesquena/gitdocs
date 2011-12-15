require 'thread'
require 'yajl'
require 'dante'
require 'socket'
require 'shell_tools'
require 'guard'

require 'gitdocs/version'
require 'gitdocs/configuration'
require 'gitdocs/runner'
require 'gitdocs/server'
require 'gitdocs/cli'
require 'gitdocs/manager'
require 'gitdocs/docfile'
require 'gitdocs/rendering'

module Gitdocs

  DEBUG = ENV['DEBUG']

  def self.start(config_root = nil, debug = DEBUG, &blk)
    @manager.stop if @manager
    @manager = Manager.new(config_root, debug, &blk)
    @manager.start
  end

  def self.restart
    @manager.restart
  end

  def self.stop
    @manager.stop
  end
end
