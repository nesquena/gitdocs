# -*- encoding : utf-8 -*-

# Wrapper for the UI notifier
class Gitdocs::Notifier
  INFO_ICON = File.expand_path('../../img/icon.png', __FILE__)

  def initialize(show_notifications)
    @show_notifications = show_notifications
    Guard::Notifier.turn_on if @show_notifications
  end

  def info(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: INFO_ICON)
    else
      puts("#{title}: #{message}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end

  def warn(title, msg)
    if @show_notifications
      Guard::Notifier.notify(msg, title: title)
    else
      Kernel.warn("#{title}: #{msg}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end

  def error(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: :failure)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end
end
