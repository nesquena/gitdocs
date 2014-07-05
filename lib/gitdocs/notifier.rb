# -*- encoding : utf-8 -*-

# Wrapper for the UI notifier
class Gitdocs::Notifier
  INFO_ICON = File.expand_path('../../img/icon.png', __FILE__)

  # Wrapper around #error for a single call to the notifier.
  # @see #error
  def self.error(title, message)
    Gitdocs::Notifier.new(true).error(title, message)
  end

  # @param [Boolean] show_notifications
  def initialize(show_notifications)
    @show_notifications = show_notifications
    Guard::Notifier.turn_on if @show_notifications
  end

  # @param [String] title
  # @param [String] title
  def info(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: INFO_ICON)
    else
      puts("#{title}: #{message}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end

  # @param [String] title
  # @param [String] title
  def warn(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end

  # @param [String] title
  # @param [String] title
  def error(title, message)
    if @show_notifications
      Guard::Notifier.notify(message, title: title, image: :failure)
    else
      Kernel.warn("#{title}: #{message}")
    end
  rescue # Prevent StandardErrors from stopping the daemon.
  end

  # @param [nil, :no_remote, String, Array<String>, Hash<String, Integer>] result
  # @param [String] root
  def merge_notification(result, root)
    return if result.nil?
    return if result == :no_remote
    return if result == :ok

    if result.kind_of?(Array)
      warn(
        'There were some conflicts',
        result.map { |f| "* #{f}" }.join("\n")
      )
    elsif result.kind_of?(Hash)
      unless result.empty?
        author_list = result.map do |author, count|
          "* #{author} (#{change_to_s(count)})"
        end
        info(
          "Updated with #{change_to_s(result)}",
          "In #{root}:\n#{author_list.join("\n")}"
        )
      end
    else
      error(
        'There was a problem synchronizing this gitdoc',
        "A problem occurred in #{root}:\n#{result}"
      )
    end
  end

  # @param [nil, :no_remote, :nothing, :conflict, String, Hash<String, Integer>] result
  # @param [String] root
  def push_notification(result, root)
    return if result.nil?
    return if result == :no_remote
    return if result == :nothing

    if result == :conflict
      warn("There was a conflict in #{root}, retrying", '')
    elsif result.kind_of?(Hash)
      info("Pushed #{change_to_s(result)}", "#{root} has been pushed")
    else
      error("BAD Could not push changes in #{root}", result.to_s)
    end
  end

  ##############################################################################

  private

  def change_to_s(count_or_hash)
    count =
      if count_or_hash.respond_to?(:values)
        count_or_hash.values.reduce(:+)
      else
        count_or_hash
      end

    "#{count} change#{count == 1 ? '' : 's'}"
  end
end
