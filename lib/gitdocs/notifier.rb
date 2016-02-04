# -*- encoding : utf-8 -*-

require 'notiffany'

# Wrapper for the UI notifier
module Gitdocs
  class Notifier
    include Singleton

    # @param [String] title
    # @param [String] message
    # @param [Boolean] show_notification
    #
    # @return [void]
    def self.info(title, message, show_notification)
      Gitdocs.log_info("#{title}: #{message}")
      if show_notification
        instance.notify(title, message, :success)
      else
        puts("#{title}: #{message}")
      end
    rescue # rubocop:disable Lint/HandleExceptions
      # Prevent StandardErrors from stopping the daemon.
    end

    # @param [String] title
    # @param [String] message
    # @param [Boolean] show_notification
    #
    # @return [void]
    def self.warn(title, message, show_notification)
      Gitdocs.log_warn("#{title}: #{message}")
      if show_notification
        instance.notify(title, message, :pending)
      else
        Kernel.warn("#{title}: #{message}")
      end
    rescue # rubocop:disable Lint/HandleExceptions
      # Prevent StandardErrors from stopping the daemon.
    end

    # @overload error(title, message)
    #   @param [String] title
    #   @param [String] message
    #
    # @overload error(title, message, show_notification)
    #   @param [String] title
    #   @param [String] message
    #   @param [Boolean] show_notification
    #
    # @return [void]
    def self.error(title, message, show_notification = true)
      Gitdocs.log_error("#{title}: #{message}")

      if show_notification
        instance.notify(title, message, :failed)
      else
        Kernel.warn("#{title}: #{message}")
      end
    rescue # rubocop:disable Lint/HandleExceptions
      # Prevent StandardErrors from stopping the daemon.
    end

    # @return [void]
    def self.disconnect
      instance.disconnect
    end

    ############################################################################

    # @private
    # @param [String] title
    # @param [String] message
    # @param [:success, :pending, :failed] type
    #
    # @return [void]
    def notify(title, message, type)
      @notifier ||= Notiffany.connect
      @notifier.notify(message, title: title, image: type)
    end

    # @private
    # @return [void]
    def disconnect
      @notifier.disconnect if @notifier
      @notifier = nil
    end
  end
end
