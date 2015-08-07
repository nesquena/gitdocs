# -*- encoding : utf-8 -*-

class Gitdocs::SyncronizationNotifier
  # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] merge_result
  # @param [nil, Symbol, Hash<String => Integer>, #to_s] push_result
  # @param [Gitdocs::Share] share
  #
  # @return [void]
  def self.notify(merge_result, push_result, share)
    notifier = Gitdocs::SyncronizationNotifier.new(share)
    notifier.merge_notify(merge_result)
    notifier.push_notify(push_result)
    nil
  end

  # @param [Gitdocs::Share] share
  def initialize(share)
    @path         = share.path
    @notification = share.notification
  end

  # @param [nil, Symbol, Array<String>, Hash<String => Integer>, #to_s] result
  # @return [void]
  def merge_notify(result)
    return if no_result?(result)

    if result.is_a?(Array)
      notifier.warn(
        'There were some conflicts',
        result.map { |f| "* #{f}" }.join("\n")
      )
    elsif result.is_a?(Hash)
      notifier.info(
        "Updated with #{change_to_s(result)}",
        "In #{@path}:\n#{author_list(result)}"
      )
    else
      notifier.error(
        'There was a problem synchronizing this gitdoc',
        "A problem occurred in #{@path}:\n#{result}"
      )
    end
  end

  # @param [nil, Symbol, Hash<String => Integer>, #to_s] result push operation
  # @return [void]
  def push_notify(result)
    return if no_result?(result)

    if result == :conflict
      notifier.warn("There was a conflict in #{@path}, retrying", '')
    elsif result.is_a?(Hash)
      notifier.info("Pushed #{change_to_s(result)}", "#{@path} has been pushed")
    else
      notifier.error("BAD Could not push changes in #{@path}", result.to_s)
    end
  end

  ##############################################################################

  private

  # @result [Object]
  # @return [Boolean]
  def no_result?(result)
    return true if result.nil?
    return true if result == :no_remote
    return true if result == :ok
    return true if result == {}
    return true if result == :nothing
    false
  end

  # @return [Gitdocs::Notifier]
  def notifier
    @notifier ||= Gitdocs::Notifier.new(@notification)
  end

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
