# -*- encoding : utf-8 -*-

# Wrapper for the UI notifier
class Gitdocs::Notifier
  INFO_ICON = File.expand_path('../../img/icon.png', __FILE__)

  # @param [String] title
  # @param [String] message
  # @param [Boolean] show_notification
  #
  # @return [void]
  def self.info(title, message, show_notification)
    Gitdocs.log_info("#{title}: #{message}")
    if show_notification
      Guard::Notifier.turn_on
      Guard::Notifier.notify(message, title: title, image: INFO_ICON)
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
      Guard::Notifier.turn_on
      Guard::Notifier.notify(message, title: title)
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
      Guard::Notifier.turn_on
      Guard::Notifier.notify(message, title: title, image: :failure)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # rubocop:disable Lint/HandleExceptions
    # Prevent StandardErrors from stopping the daemon.
  end
end
