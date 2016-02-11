# -*- encoding : utf-8 -*-

require 'find'
require 'rugged'
require 'grit'
require 'gitdocs/repository/path'
require 'gitdocs/repository/invalid_error'
require 'gitdocs/repository/committer'

# rubocop:disable ClassLength
# This class is long, but at the moment everything in it seems to be
# appropriate.

# Wrapper for accessing the shared git repositories.
# Rugged or Grit will be used, in that order of preference, depending
# upon the features which are available with each option.
#
# @note If a repository is invalid then query methods will return nil, and
#   command methods will raise exceptions.
module Gitdocs
  class Repository
    attr_reader :invalid_reason

    class FetchError < StandardError ; end
    class MergeError < StandardError ; end

    # Initialize the repository on the specified path. If the path is not valid
    # for some reason, the object will be initialized but it will be put into an
    # invalid state.
    # @see #valid?
    # @see #invalid_reason
    #
    # @param [String, Share] path_or_share
    def initialize(path_or_share)
      path = path_or_share
      if path_or_share.respond_to?(:path)
        path = path_or_share.path
        @remote_name = path_or_share.remote_name
        @branch_name = path_or_share.branch_name
      end

      @rugged               = Rugged::Repository.new(path)
      @grit                 = Grit::Repo.new(path)
      Grit::Git.git_timeout = 120
      @invalid_reason       = nil
      @commit_message_path  = abs_path('.gitmessage~')
    rescue Rugged::OSError
      @invalid_reason = :directory_missing
    rescue Rugged::RepositoryError
      @invalid_reason = :no_repository
    end

    # Clone a repository, and create the destination path if necessary.
    #
    # @param [String] path to clone the repository to
    # @param [String] remote URI of the git repository to clone
    #
    # @raise [RuntimeError] if the clone fails
    #
    # @return [Gitdocs::Repository]
    def self.clone(path, remote)
      FileUtils.mkdir_p(File.dirname(path))
      # TODO: determine how to do this with rugged, and handle SSH and HTTPS
      #   credentials.
      Grit::Git.new(path).clone({ raise: true, quiet: true }, remote, path)

      repository = new(path)
      fail("Unable to clone into #{path}") unless repository.valid?
      repository
    rescue Grit::Git::GitTimeout
      raise("Unable to clone into #{path} because it timed out")
    rescue Grit::Git::CommandFailed => e
      raise("Unable to clone into #{path} because of #{e.err}")
    end

    # @return [String]
    def root
      return nil unless valid?
      @rugged.path.sub(/.\.git./, '')
    end

    # @return [Boolean]
    def valid?
      !@invalid_reason
    end

    # @return [nil] if the repository is invalid
    # @return [Array<String>] sorted list of remote branches
    def available_remotes
      return nil unless valid?
      @rugged.branches.each_name(:remote).sort
    end

    # @return [nil] if the repository is invalid
    # @return [Array<String>] sorted list of local branches
    def available_branches
      return nil unless valid?
      @rugged.branches.each_name(:local).sort
    end

    # @return [nil] if there are no commits present
    # @return [String] oid of the HEAD of the working directory
    def current_oid
      @rugged.head.target_id
    rescue Rugged::ReferenceError
      nil
    end

    # Is the working directory dirty
    #
    # @return [Boolean]
    def dirty?
      return false unless valid?

      return Dir.glob(abs_path('*')).any? unless current_oid
      @rugged.diff_workdir(current_oid, include_untracked: true).deltas.any?
    end

    # @return [Boolean]
    def need_sync?
      return false unless valid?
      return false unless remote?
      remote_oid != current_oid
    end

    # @param [String] term
    # @yield [file, context] Gives the files and context for each of the results
    # @yieldparam file [String]
    # @yieldparam context [String]
    def grep(term, &block)
      @grit.git.grep(
        { raise: true, bare: false, chdir: root, ignore_case: true },
        term
      ).scan(/(.*?):([^\n]*)/, &block)
    rescue Grit::Git::GitTimeout
      # TODO: add logging to record the error details
      ''
    rescue Grit::Git::CommandFailed
      # TODO: add logging to record the error details if they are not just
      # nothing found
      ''
    end

    # Fetch all the remote branches
    #
    # @raise [FetchError] if there is an error return message
    #
    # @return [nil] if the repository is invalid
    # @return [:no_remote] if the remote is not yet set
    # @return [:ok] if the fetch worked
    def fetch
      return nil unless valid?
      return :no_remote unless remote?

      @rugged.remotes.each { |x| @grit.remote_fetch(x.name) }
      :ok
    rescue Grit::Git::GitTimeout
      raise(FetchError, "Fetch timed out for #{root}")
    rescue Grit::Git::CommandFailed => e
      raise(FetchError, e.err)
    end

    # Merge the repository
    #
    # @raise [MergeError] if there is an error, it it will include the message
    #
    # @return [nil] if the repository is invalid
    # @return [:no_remote] if the remote is not yet set
    # @return [Array<String>] if there is a conflict return the Array of
    #   conflicted file names
    # @return (see #author_count) if merged with no errors or conflicts
    def merge
      return nil        unless valid?
      return :no_remote unless remote?
      return :ok        unless remote_oid
      return :ok        if remote_oid == current_oid

      last_oid = current_oid
      @grit.git.merge(
        { raise: true, chdir: root },
        "#{@remote_name}/#{@branch_name}"
      )
      author_count(last_oid)
    rescue Grit::Git::GitTimeout
      raise(MergeError, "Merge timed out for #{root}")
    rescue Grit::Git::CommandFailed => e
      # HACK: The rugged in-memory index will not have been updated after the
      # Grit merge command. Reload it before checking for conflicts.
      @rugged.index.reload
      raise(MergeError, e.err) unless @rugged.index.conflicts?
      mark_conflicts
    end

    # @return [nil]
    # @return (see Gitdocs::Repository::Comitter#commit)
    def commit
      return unless valid?
      Committer.new(root).commit
    end

    # Push the repository
    #
    # @return [nil] if the repository is invalid
    # @return [:no_remote] if the remote is not yet set
    # @return [:nothing] if there was nothing to do
    # @return [String] if there is an error return the message
    # @return (see #author_count) if committed and pushed without errors or conflicts
    def push
      return            unless valid?
      return :no_remote unless remote?
      return :nothing   unless current_oid
      return :nothing   if remote_oid == current_oid

      last_oid = remote_oid
      @grit.git.push({ raise: true }, @remote_name, @branch_name)
      author_count(last_oid)
    rescue Grit::Git::CommandFailed => e
      return :conflict if e.err[/\[rejected\]/]
      e.err # return the output on error
    end

    # Get the count of commits by author from the head to the specified oid.
    #
    # @param [String] last_oid
    #
    # @return [Hash<String, Int>]
    def author_count(last_oid)
      walker = head_walker
      walker.hide(last_oid) if last_oid
      walker.reduce(Hash.new(0)) do |result, commit|
        result["#{commit.author[:name]} <#{commit.author[:email]}>"] += 1
        result
      end
    rescue Rugged::ReferenceError
      {}
    rescue Rugged::OdbError
      {}
    end

    # @param (see Gitdocs::Repository::Comitter#write_commit_message)
    # @return [void]
    def write_commit_message(message)
      return unless valid?
      Committer.new(root).write_commit_message(message)
    end

    # Excluding the initial commit (without a parent) which keeps things
    # consistent with the original behaviour.
    # TODO: reconsider if this is the correct behaviour
    #
    # @param [String] relative_path
    # @param [Integer] limit the number of commits which will be returned
    #
    # @return [Array<Rugged::Commit>]
    def commits_for(relative_path, limit)
      # TODO: should add a filter here for checking that the commit actually has
      # an associated blob.
      commits = head_walker.select do |commit|
        commit.parents.size == 1 && commit.diff(paths: [relative_path]).size > 0
      end
      # TODO: should re-write this limit in a way that will skip walking all of
      # the commits.
      commits.first(limit)
    end

    # @param [String] relative_path
    #
    # @return [Rugged::Commit]
    def last_commit_for(relative_path)
      head_walker.find { |commit| commit.diff(paths: [relative_path]).size > 0 }
    end

    # @param [String] relative_path
    # @param [String] oid
    def blob_at(relative_path, ref)
      @rugged.blob_at(ref, relative_path)
    end

    ##############################################################################

    private

    # @return [Boolean]
    def remote?
      @rugged.remotes.any?
    end

    # @return [nil]
    # @return [String]
    def remote_oid
      branch = @rugged.branches["#{@remote_name}/#{@branch_name}"]
      return unless branch
      branch.target_id
    end

    def head_walker
      walker = Rugged::Walker.new(@rugged)
      walker.sorting(Rugged::SORT_DATE)
      walker.push(@rugged.head.target)
      walker
    end

    def read_and_delete_commit_message_file
      return 'Auto-commit from gitdocs' unless File.exist?(@commit_message_path)

      message = File.read(@commit_message_path)
      File.delete(@commit_message_path)
      message
    end

    def mark_empty_directories
      Find.find(root).each do |path| # rubocop:disable Style/Next
        Find.prune if File.basename(path) == '.git'
        if File.directory?(path) && Dir.entries(path).count == 2
          FileUtils.touch(File.join(path, '.gitignore'))
        end
      end
    end

    def mark_conflicts
      # assert(@rugged.index.conflicts?)

      # Collect all the index entries by their paths.
      index_path_entries = Hash.new { |h, k| h[k] = Array.new }
      @rugged.index.map do |index_entry|
        index_path_entries[index_entry[:path]].push(index_entry)
      end

      # Filter to only the conflicted entries.
      conflicted_path_entries = index_path_entries.delete_if { |_k, v| v.length == 1 }

      conflicted_path_entries.each_pair do |path, index_entries|
        # Write out the different versions of the conflicted file.
        index_entries.each do |index_entry|
          filename, extension = index_entry[:path].scan(/(.*?)(|\.[^\.]+)$/).first
          author       = ' original' if index_entry[:stage] == 1
          short_oid    = index_entry[:oid][0..6]
          new_filename = "#{filename} (#{short_oid}#{author})#{extension}"
          File.open(abs_path(new_filename), 'wb') do |f|
            f.write(Rugged::Blob.lookup(@rugged, index_entry[:oid]).content)
          end
        end

        # And remove the original.
        FileUtils.remove(abs_path(path), force: true)
      end

      # NOTE: Let commit be handled by the next regular commit.

      conflicted_path_entries.keys
    end

    def abs_path(*path)
      File.join(root, *path)
    end
  end
end
