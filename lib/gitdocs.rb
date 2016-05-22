# -*- encoding : utf-8 -*-

require 'thread'
require 'dante'
require 'socket'
require 'grit'
require 'rugged'
require 'table_print'
require 'notiffany'
require 'launchy'
require 'celluloid'
require 'listen'
require 'reel/rack'

require 'gitdocs/version'
require 'gitdocs/initializer'
require 'gitdocs/share'
require 'gitdocs/configuration'
require 'gitdocs/cli'
require 'gitdocs/manager'
require 'gitdocs/synchronizer'
require 'gitdocs/notifier'
require 'gitdocs/git_notifier'
require 'gitdocs/repository'
require 'gitdocs/repository/path'
require 'gitdocs/repository/committer'
require 'gitdocs/settings_app'
require 'gitdocs/browser_app'
require 'gitdocs/search'

module Gitdocs
  # @return [String]
  def self.log_path
    File.expand_path('log', Initializer.root_dirname)
  end

  # @param [String] message
  # @return [void]
  def self.log_debug(message)
    init_log
    Celluloid.logger.debug(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_info(message)
    init_log
    Celluloid.logger.info(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_warn(message)
    init_log
    Celluloid.logger.warn(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_error(message)
    init_log
    Celluloid.logger.error(message)
  end

  ##############################################################################

  private_class_method

  # @return [void]
  def self.init_log
    return if @initialized

    # Initialize the logger
    log_output = Initializer.foreground ? STDOUT : log_path
    Celluloid.logger = Logger.new(log_output)
    Celluloid.logger.level = Initializer.verbose ? Logger::DEBUG : Logger::INFO
    @initialized = true
  end
end
