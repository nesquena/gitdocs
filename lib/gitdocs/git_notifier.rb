# -*- encoding : utf-8 -*-

# Notifications about git specific operations
module Gitdocs
  class GitNotifier
    # @param [String] root
    # @param [Boolean] show_notifications
    def initialize(root, show_notifications)
      @root               = root
      @show_notifications = show_notifications
    end

    # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] result
    #
    # @return [void]
    def for_merge(result)
      return if result.nil?
      return if result == :no_remote
      return if result == :ok
      return if result == {}

      if result.is_a?(Array)
        Notifier.warn(
          'There were some conflicts',
          result.map { |f| "* #{f}" }.join("\n"),
          @show_notifications
        )
      elsif result.is_a?(Hash)
        Notifier.info(
          "Updated with #{change_to_s(result)}",
          "In #{@root}:\n#{author_list(result)}",
          @show_notifications
        )
      else
        Notifier.error(
          'There was a problem synchronizing this gitdoc',
          "A problem occurred in #{@root}:\n#{result}",
          @show_notifications
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
        Notifier.warn(
          "There was a conflict in #{@root}, retrying",
          '',
          @show_notifications
        )
      elsif result.is_a?(Hash)
        Notifier.info(
          "Pushed #{change_to_s(result)}",
          "#{@root} has been pushed",
          @show_notifications
        )
      else
        Notifier.error(
          "BAD Could not push changes in #{@root}",
          result.to_s,
          @show_notifications
        )
      end
      nil
    end

    # @param [Exception] exception
    #
    # @return [void]
    def on_error(exception)
      Notifier.error(
        "Unexpected error when fetching/pushing in #{@root}",
        exception.to_s,
        @show_notifications
      )
      nil
    end

    ############################################################################

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
end
