# -*- encoding : utf-8 -*-

require 'gitdocs/version'
require 'gitdocs/initializer'
require 'gitdocs/share'
require 'gitdocs/configuration'
require 'gitdocs/cli'
require 'gitdocs/repository'
require 'gitdocs/search'

module Gitdocs
  # @return [String]
  def self.log_path
    File.expand_path('log', Initializer.root_dirname)
  end

  # @param [String] message
  # @return [void]
  def self.log_debug(message)
    Celluloid.logger.debug(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_info(message)
    Celluloid.logger.info(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_warn(message)
    Celluloid.logger.warn(message)
  end

  # @param [String] message
  # @return [void]
  def self.log_error(message)
    Celluloid.logger.error(message)
  end
end
