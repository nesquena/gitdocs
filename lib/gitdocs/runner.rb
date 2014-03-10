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
      result = @repository.pull

      return if result.nil? || result == :no_remote

      if result.kind_of?(String)
        @notifier.error(
          'There was a problem synchronizing this gitdoc',
          "A problem occurred in #{root}:\n#{result}"
        )
        return
      end

      if result == :ok
        author_change_count = latest_author_count
        unless author_change_count.empty?
          author_list = author_change_count.map { |author, count| "* #{author} (#{change_count(count)})" }.join("\n")
          @notifier.info(
            "Updated with #{change_count(author_change_count)}",
            "In '#{root}':\n#{author_list}"
          )
        end
      else
        #assert result.kind_of?(Array)
        @notifier.warn(
          'There were some conflicts',
          result.map { |f| "* #{f}" }.join("\n")
        )
      end

      push_changes
    end

    def push_changes
      message_file = File.expand_path('.gitmessage~', root)
      if File.exist?(message_file)
        message = File.read(message_file)
        File.delete(message_file)
      else
        message = 'Auto-commit from gitdocs'
      end

      result = @repository.push(@last_synced_revision, message)

      return if result.nil? || result == :no_remote || result == :nothing
      level, title, message = case result
      when :ok       then [:info, "Pushed #{change_count(latest_author_count)}", "'#{root}' has been pushed"]
      when :conflict then [:warn, "There was a conflict in #{root}, retrying", '']
      else
        # assert result.kind_of?(String)
        [:error, "BAD Could not push changes in #{root}", result]
        # TODO: need to add a status on shares so that the push problem can be
        # displayed.
      end
      @notifier.send(level, title, message)
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

    def change_count(count_or_hash)
      count = if count_or_hash.respond_to?(:values)
        count_or_hash .values.reduce(:+)
      else
        count_or_hash
      end

      "#{count} change#{count == 1 ? '' : 's'}"
    end
  end
end
