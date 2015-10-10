# -*- encoding : utf-8 -*-

# Notifications about git specific operations
class Gitdocs::GitNotifier
  # @param [String] root
  # @param [Boolean] show_notification
  def initialize(root, show_notification)
    @root     = root
    @notifier = Gitdocs::Notifier.new(show_notification)
  end

  # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] result of merge
  #
  # @return [void]
  def for_merge(result)
    return if result.nil?
    return if result == :no_remote
    return if result == :ok
    return if result == {}

    if result.is_a?(Array)
      @notifier.warn(
        'There were some conflicts',
        result.map { |f| "* #{f}" }.join("\n")
      )
    elsif result.is_a?(Hash)
      @notifier.info(
        "Updated with #{change_to_s(result)}",
        "In #{@root}:\n#{author_list(result)}"
      )
    else
      @notifier.error(
        'There was a problem synchronizing this gitdoc',
        "A problem occurred in #{@root}:\n#{result}"
      )
    end
    nil
  end

  # @param [nil, Symbol, Hash<String => Integer>, #to_s] result of push
  #
  # @return [void]
  def for_push(result)
    return if result.nil?
    return if result == :no_remote
    return if result == :nothing

    if result == :conflict
      @notifier.warn("There was a conflict in #{@root}, retrying", '')
    elsif result.is_a?(Hash)
      @notifier.info("Pushed #{change_to_s(result)}", "#{@root} has been pushed")
    else
      @notifier.error("BAD Could not push changes in #{@root}", result.to_s)
    end
    nil
  end

  # @param [Exception] exception
  #
  # @return [void]
  def on_error(exception)
    @notifier.error(
      "Unexpected error when fetching/pushing in #{@root}",
      exception.to_s
    )
    nil
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
