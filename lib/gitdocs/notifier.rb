# -*- encoding : utf-8 -*-

# Wrapper for the UI notifier
class Gitdocs::Notifier
  INFO_ICON = File.expand_path('../../img/icon.png', __FILE__)

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
    Gitdocs::Notifier.new(show_notification).error(title, message)
  end

  # @param [Boolean] show_notifications
  def initialize(show_notifications)
    @show_notifications = show_notifications
    Guard::Notifier.turn_on if @show_notifications
  end

  # @param [String] title
  # @param [String] message
  def info(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: INFO_ICON)
    else
      puts("#{title}: #{message}")
    end
  rescue # rubocop:disable Lint/HandleExceptions
    # Prevent StandardErrors from stopping the daemon.
  end

  # @param [String] title
  # @param [String] message
  def warn(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # rubocop:disable Lint/HandleExceptions
    # Prevent StandardErrors from stopping the daemon.
  end

  # @param [String] title
  # @param [String] message
  def error(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: :failure)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # rubocop:disable Lint/HandleExceptions
    # Prevent StandardErrors from stopping the daemon.
  end
end
