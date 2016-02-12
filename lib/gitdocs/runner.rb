# -*- encoding : utf-8 -*-

require 'guard'

module Gitdocs
  class Runner
    def self.start_all(shares)
      runners = shares.map { |share| Runner.new(share) }
      runners.each(&:run)
      runners
    end

    def initialize(share)
      @share = share
      @polling_interval = share.polling_interval
      @repository       = Repository.new(share)
      @git_notifier     = GitNotifier.new(share.path, share.notification)
    end

    def root
      @repository.root
    end

    def run
      return false unless @repository.valid?

      mutex = Mutex.new

      # Pull changes from remote repository
      syncer = proc do
        EM.defer(proc do
          mutex.synchronize { sync_changes }
        end, proc do
          EM.add_timer(@polling_interval) do
            syncer.call
          end
        end)
      end
      syncer.call
      # Listen for changes in local repository

      EM.defer(proc do
        listener = Guard::Listener.select_and_init(
          root, watch_all_modifications: true
        )
        listener.on_change do |directories|
          directories.uniq!
          directories.delete_if { |d| d =~ /\/\.git/ }
          unless directories.empty?
            EM.next_tick do
              EM.defer(proc do
                mutex.synchronize { sync_changes }
              end, proc {})
            end
          end
        end
        listener.start
      end, proc { EM.stop_reactor })
    end

    # @return [void]
    def sync_changes
      return unless @repository.valid?

      result = @repository.synchronize(@share.sync_type)
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
