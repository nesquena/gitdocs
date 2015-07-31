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

  # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] merge_result
  # @param [nil, Symbol, Hash<String => Integer>, #to_s] push_result
  # @param [String] root
  # @param [Boolean] show_notification
  #
  # @return [void]
  def self.sync_result(merge_result, push_result, root, show_notification)
    notifier = Gitdocs::Notifier.new(show_notification)
    notifier.merge_notification(merge_result, root)
    notifier.push_notification(push_result, root)
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

  # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] result
  # @param [String] root
  def merge_notification(result, root)
    return if result.nil?
    return if result == :no_remote
    return if result == :ok
    return if result == {}

    if result.is_a?(Array)
      warn(
        'There were some conflicts',
        result.map { |f| "* #{f}" }.join("\n")
      )
    elsif result.is_a?(Hash)
      info(
        "Updated with #{change_to_s(result)}",
        "In #{root}:\n#{author_list(result)}"
      )
    else
      error(
        'There was a problem synchronizing this gitdoc',
        "A problem occurred in #{root}:\n#{result}"
      )
    end
  end

  # @param [nil, Symbol, Hash<String => Integer>, #to_s] result push operation
  # @param [String] root
  def push_notification(result, root)
    return if result.nil?
    return if result == :no_remote
    return if result == :nothing

    if result == :conflict
      warn("There was a conflict in #{root}, retrying", '')
    elsif result.is_a?(Hash)
      info("Pushed #{change_to_s(result)}", "#{root} has been pushed")
    else
      error("BAD Could not push changes in #{root}", result.to_s)
    end
  end

  ##############################################################################

  private

  # @param [Hash<String => Integer>] changes
  # @return [String]
  def author_list(changes)
    changes
      .map { |author, count| "* #{author} (#{change_to_s(count)})" }
      .join("\n")
  end

  # @param [Integer, Hash<String => Integer>] count_or_hash
  # @return [String]
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
