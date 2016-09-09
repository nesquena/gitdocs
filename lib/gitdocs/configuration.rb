# -*- encoding : utf-8 -*-

require 'active_record'

module Gitdocs
  class Configuration
    # @return [Boolean]
    def self.start_web_frontend
      Config.global.start_web_frontend
    end

    # @return [Integer]
    def self.web_frontend_port
      Config.global.web_frontend_port
    end

    # @return [String]
    def self.web_frontend_host
      Config.global.web_frontend_host
    end

    # @param [Hash] new_config
    def self.update(new_config)
      Config.global.update_attributes(new_config)
    end

    # NOTE: This record has been kept as a subclass to avoid changing the
    # database table. There are other ways to achieve this, but this seemed most
    # clear for now. [2015-06-26 -- acant]
    #
    # @!attribute start_web_frontend
    #   @return [Boolean] defaults to true
    # @!attribute web_frontend_port
    #   @return [Integer] defaults to 8888
    # @!attribute web_frontend_host
    #   @return [String] defaults to '127.0.0.1'
    class Config < ActiveRecord::Base
      # @return [Gitdocs::Configuration::Config]
      def self.global
        fail if all.size > 1
        create! if all.empty?
        all.first
      end
    end
  end
end
