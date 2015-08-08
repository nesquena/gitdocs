# -*- encoding : utf-8 -*-

# Wrapper for the UI notifier
class Gitdocs::Notifier
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
  end

  # @param [String] title
  # @param [String] message
  #
  # @return [void]
  def info(title, message)
    notify_or_warn(title, message, :success)
  end

  # @param [String] title
  # @param [String] message
  #
  # @return [void]
  def warn(title, message)
    notify_or_warn(title, message, :pending)
  end

  # @param [String] title
  # @param [String] message
  #
  # @return [void]
  def error(title, message)
    notify_or_warn(title, message, :failed)
  end

  private

  # @param [String] title
  # @param [String] message
  # @param [String] image
  #
  # @return [void]
  def notify_or_warn(title, message, image)
    if @show_notifications
      Gitdocs.notify(message, title: title, image: image)
    else
      output = "#{title}: #{message}"
      if image == :success
        puts(output)
      else
        Kernel.warn(output)
      end
    end
  rescue # rubocop:disable Lint/HandleExceptions
    # Prevent StandardErrors from stopping the daemon.
  end
end
