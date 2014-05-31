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
      @notifier         = Gitdocs::Notifier.new(@share.notification)
      @repository       = Gitdocs::Repository.new(share)
    end

    def root
      @repository.root
    end

    def run
      return false unless @repository.valid?

      @last_synced_revision = @repository.current_oid

      mutex = Mutex.new

      @notifier.info('Running gitdocs!', "Running gitdocs in '#{root}'")

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
        listener = Guard::Listener.select_and_init(root, watch_all_modifications: true)
        listener.on_change do |directories|
          directories.uniq!
          directories.delete_if { |d| d =~ /\/\.git/ }
          unless directories.empty?
            EM.next_tick do
              EM.defer(proc do
                mutex.synchronize { push_changes }
              end, proc {})
            end
          end
        end
        listener.start
      end, proc { EM.stop_reactor })
    end

    def clear_state
      @state = nil
    end

    def sync_changes
      fetch_result = @repository.fetch
      return unless fetch_result == :ok

      merge_result = @repository.merge
      merge_result = latest_author_count if merge_result == :ok
      @notifier.merge_notification(merge_result, root)

      push_changes unless merge_result.kind_of?(String)
    end

    def push_changes
      message_file = File.expand_path('.gitmessage~', root)
      if File.exist?(message_file)
        message = File.read(message_file)
        File.delete(message_file)
      else
        message = 'Auto-commit from gitdocs'
      end
      @repository.commit(message)

      result = @repository.push
      result = latest_author_count if result == :ok
      @notifier.push_notification(result, root)
    rescue => e
      # Rescue any standard exceptions which come from the push related
      # commands. This will prevent problems on a single share from killing
      # the entire daemon.
      @notifier.error("Unexpected error pushing changes in #{root}", "#{e}")
      # TODO: get logging and/or put the error message into a status field in the database
    end

    ############################################################################
    private

    # Update the author count for the last synced changes, and then update the
    # last synced revision id.
    #
    # @return [Hash<String,Int>]
    def latest_author_count
      last_oid = @last_synced_revision
      @last_synced_revision = @repository.current_oid

      @repository.author_count(last_oid)
    end
  end
end
