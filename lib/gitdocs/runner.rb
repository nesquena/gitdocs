module Gitdocs
  class Runner
    include ShellTools

    attr_reader :listener

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

    SearchResult = Struct.new(:file, :context)
    def search(term)
      return [] if term.empty?

      results = []
      if result_test = sh_string("git grep -i #{ShellTools.escape(term)}")
        result_test.scan(/(.*?):([^\n]*)/) do |(file, context)|
          if result = results.find { |s| s.file == file }
            result.context += ' ... ' + context
          else
            results << SearchResult.new(file, context)
          end
        end
      end
      results
    end

    def run
      return false unless @repository.valid?

      @current_remote       = @share.remote_name
      @current_branch       = @share.branch_name
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
      out, status = sh_with_code("git fetch --all && git merge #{@current_remote}/#{@current_branch}")
      if status.success?
        author_change_count = latest_author_count
        unless author_change_count.empty?
          author_list = author_change_count.map { |author, count| "* #{author} (#{change_count(count)})" }.join("\n")
          @notifier.info(
            "Updated with #{change_count(author_change_count)}",
            "In '#{root}':\n#{author_list}"
          )
        end
        push_changes
      elsif out[/CONFLICT/]
        conflicted_files = sh('git ls-files -u --full-name -z').split("\0")
          .reduce(Hash.new { |h, k| h[k] = [] }) do|h, line|
            parts = line.split(/\t/)
            h[parts.last] << parts.first.split(/ /)
            h
          end
        @notifier.warn(
          'There were some conflicts',
          "#{conflicted_files.keys.map { |f| "* #{f}" }.join("\n")}"
        )
        conflicted_files.each do |conflict, ids|
          conflict_start, conflict_end = conflict.scan(/(.*?)(|\.[^\.]+)$/).first
          ids.each do |(mode, sha, id)|
            author =  ' original' if id == '1'
            system("cd #{root} && git show :#{id}:#{conflict} > '#{conflict_start} (#{sha[0..6]}#{author})#{conflict_end}'")
          end
          system("cd #{root} && git rm #{conflict}") || fail
        end
        push_changes
      elsif sh_string('git remote').nil? # no remote to pull from
        # Do nothing, no remote repo yet
      else
        @notifier.error(
          'There was a problem synchronizing this gitdoc',
          "A problem occurred in #{root}:\n#{out}"
        )
      end
    end

    def push_changes
      message_file = File.expand_path('.gitmessage~', root)
      if File.exist? message_file
        message = File.read message_file
        File.delete message_file
      else
        message = 'Auto-commit from gitdocs'
      end
      sh 'find . -type d -regex ``./[^.].*'' -empty -exec touch \'{}/.gitignore\' \;'
      sh 'git add .'
      sh "git commit -a -m #{ShellTools.escape(message)}" unless sh('git status -s').strip.empty?
      if @last_synced_revision.nil? || sh('git status')[/branch is ahead/]
        out, code = sh_with_code("git push #{@current_remote} #{@current_branch}")
        if code.success?
          @notifier.info(
            "Pushed #{change_count(latest_author_count)}",
            "'#{root}' has been pushed"
          )
        elsif @last_synced_revision.nil?
          # ignorable
        elsif out[/\[rejected\]/]
          @notifier.warn("There was a conflict in #{root}, retrying", '')
        else
          @notifier.error("BAD Could not push changes in #{root}", out)
          # TODO: need to add a status on shares so that the push problem can be
          # displayed.
        end
      end
    rescue => e
      # Rescue any standard exceptions which come from the push related
      # commands. This will prevent problems on a single share from killing
      # the entire daemon.
      @notifier.error("Unexpected error pushing changes in #{root}", "#{e}")
      # TODO: get logging and/or put the error message into a status field in the database
    end

    # sh_string("git config branch.`git branch | grep '^\*' | sed -e 's/\* //'`.remote", "origin")
    def sh_string(cmd, default = nil)
      val = sh(cmd).strip rescue nil
      val.nil? || val.empty? ? default : val
    end

    # Run in shell, return both status and output
    # @see #sh
    def sh_with_code(cmd)
      ShellTools.sh_with_code(cmd, root)
    end

    ############################################################################
    private

    # Update the author count for the last synced changes, and then update the
    # last synced revision id.
    #
    # @return [Hash<String,Int]
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
