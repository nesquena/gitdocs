# -*- encoding : utf-8 -*-

module Gitdocs
  class Synchronizer
    include Celluloid
    finalizer :stop_timers

    # @param [Gitdocs::Share] share
    def initialize(share)
      @git_notifier = GitNotifier.new(share.path, share.notification)
      @repository   = Repository.new(share)
      @sync_type    = share.sync_type

      # Always to an initial synchronization when beginning.
      synchronize

      @timer        = every(share.polling_interval) { synchronize }
    end

    # @return [void]
    def stop_timers
      return unless @timer
      @timer.cancel
    end

    # @return [void]
    def synchronize
      return unless @repository.valid?

      result = @repository.synchronize(@sync_type)
      @git_notifier.for_merge(result[:merge])
      @git_notifier.for_push(result[:push])
    rescue => e
      # Rescue any standard exceptions which come from the push related
      # commands. This will prevent problems on a single share from killing
      # the entire daemon.
      @git_notifier.on_error(e)
    end
  end
end
