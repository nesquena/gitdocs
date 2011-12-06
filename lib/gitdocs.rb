require 'gitdocs/version'
require 'gitdocs/configuration'
require 'gitdocs/runner'
require 'gitdocs/server'
require 'gitdocs/cli'
require 'gitdocs/manager'
require 'thread'
require 'rb-fsevent'
require 'growl'
require 'yajl'
require 'dante'
require 'socket'

module Gitdocs

  DEBUG = ENV['DEBUG']

  def self.run(config_root = nil, debug = DEBUG, &blk)
    @manager = Manager.new(config_root, debug, &blk)
    @manager.run
  end

  def self.restart
    @manager.restart
  end
end
