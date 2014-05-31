# -*- encoding : utf-8 -*-
require 'find'

# Wrapper for accessing the shared git repositories.
# Rugged or Grit will be used, in that order of preference, depending
# upon the features which are available with each option.
#
# @note If a repository is invalid then query methods will return nil, and
#   command methods will raise exceptions.
#
class Gitdocs::Repository
  attr_reader :invalid_reason

  # Initialize the repository on the specified path. If the path is not valid
  # for some reason, the object will be initialized but it will be put into an
  # invalid state.
  # @see #valid?
  # @see #invalid_reason
  #
  # @param [String, Configuration::Share] path_or_share
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
  rescue Grit::Git::GitTimeout => e
    fail("Unable to clone into #{path} because it timed out")
  rescue Grit::Git::CommandFailed => e
    fail("Unable to clone into #{path} because of #{e.err}")
  end

  RepoDescriptor = Struct.new(:name, :index)

  # Search across multiple repositories
  #
  # @param [String] term
  # @param [Array<Repository>} repositories
  #
  # @return [Hash<RepoDescriptor, Array<SearchResult>>]
  def self.search(term, repositories)
    results = {}
    repositories.each_with_index do |repository, index|
      descriptor = RepoDescriptor.new(repository.root, index)
      results[descriptor] = repository.search(term)
    end
    results.delete_if { |key, value| value.empty? }
  end

  SearchResult = Struct.new(:file, :context)

  # Search a single repository
  #
  # @param [String] term
  #
  # @return [Array<SearchResult>]
  def search(term)
    return [] if term.empty?

    results = []
    options = { raise: true, bare: false, chdir: root, ignore_case: true }
    @grit.git.grep(options, term).scan(/(.*?):([^\n]*)/) do |(file, context)|
      if result = results.find { |s| s.file == file }
        result.context += ' ... ' + context
      else
        results << SearchResult.new(file, context)
      end
    end
    results
  rescue Grit::Git::GitTimeout => e
    # TODO: add logging to record the error details
    []
  rescue Grit::Git::CommandFailed => e
    # TODO: add logging to record the error details if they are not just
      # nothing found
    []
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
    Rugged::Branch.each_name(@rugged, :remote).sort
  end

  # @return [nil] if the repository is invalid
  # @return [Array<String>] sorted list of local branches
  def available_branches
    return nil unless valid?
    Rugged::Branch.each_name(@rugged, :local).sort
  end

  # @return [nil] if there are no commits present
  # @return [String] oid of the HEAD of the working directory
  def current_oid
    @rugged.head.target
  rescue Rugged::ReferenceError
    nil
  end

  # Fetch all the remote branches
  #
  # @return [nil] if the repository is invalid
  # @return [:no_remote] if the remote is not yet set
  # @return [String] if there is an error return the message
  # @return [:ok] if the fetch worked
  def fetch
    return nil unless valid?
    return :no_remote unless has_remote?

    @rugged.remotes.each { |x| @grit.remote_fetch(x.name) }
    :ok
  rescue Grit::Git::GitTimeout
    "Fetch timed out for #{root}"
  rescue Grit::Git::CommandFailed => e
    e.err
  end

  # Merge the repository
  #
  # @return [nil] if the repository is invalid
  # @return [:no_remote] if the remote is not yet set
  # @return [String] if there is an error return the message
  # @return [Array<String>] if there is a conflict return the Array of
  #   conflicted file names
  # @return [:ok] if the merged with no errors or conflicts
  def merge
    return nil unless valid?
    return :no_remote unless has_remote?
    return :ok if remote_branch.nil? || remote_branch.tip.oid == current_oid

    @grit.git.merge({ raise: true, chdir: root }, "#{@remote_name}/#{@branch_name}")
    :ok
  rescue Grit::Git::GitTimeout
    "Merge timed out for #{root}"
  rescue Grit::Git::CommandFailed => e
    # HACK: The rugged in-memory index will not have been updated after the
    # Grit merge command. Reload it before checking for conflicts.
    @rugged.index.reload
    return e.err unless @rugged.index.conflicts?

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
        File.open(File.join(root, new_filename), 'wb') do |f|
          f.write(Rugged::Blob.lookup(@rugged, index_entry[:oid]).content)
        end
      end

      # And remove the original.
      FileUtils.remove(File.join(root, path), force: true)
    end

    # NOTE: Let commit be handled by the next regular commit.

    conflicted_path_entries.keys
  end

  # Commit the working directory
  #
  # @param [String] message
  #
  # @return [nil] if the repository is invalid
  # @return [Boolean] whether a commit was made or not
  def commit(message)
    return nil unless valid?

    # Mark any empty directories so they will be committed
    Find.find(root).each do |path|
      Find.prune if File.basename(path) == '.git'
      if File.directory?(path) && Dir.entries(path).count == 2
        FileUtils.touch(File.join(path, '.gitignore'))
      end
    end

    # Check if there are uncommitted changes
    dirty =
      if current_oid.nil?
        Dir.glob(File.join(root, '*')).any?
      else
        @rugged.diff_workdir(current_oid, include_untracked: true).deltas.any?
      end

    # Commit any changes in the working directory.
    if dirty
      Dir.chdir(root) do
        @rugged.index.add_all
        @rugged.index.update_all
      end
      @rugged.index.write
      @grit.commit_index(message)
      true
    else
      false
    end
  end

  # Push the repository
  #
  # @return [nil] if the repository is invalid
  # @return [:no_remote] if the remote is not yet set
  # @return [:nothing] if there was nothing to do
  # @return [String] if there is an error return the message
  # @return [:ok] if committed and pushed without errors or conflicts
  def push
    return nil unless valid?
    return :no_remote unless has_remote?

    return :nothing if current_oid.nil?

    if remote_branch.nil? || remote_branch.tip.oid != current_oid
      begin
        @grit.git.push({ raise: true }, @remote_name, @branch_name)
        :ok
      rescue Grit::Git::CommandFailed => e
        return :conflict if e.err[/\[rejected\]/]
        e.err # return the output on error
      end
    else
      :nothing
    end
  end

  # Get the count of commits by author from the head to the specified oid.
  #
  # @param [String] last_oid
  #
  # @return [Hash<String, Int>]
  def author_count(last_oid)
    walker = head_walker
    walker.hide(last_oid) if last_oid
    walker.inject(Hash.new(0)) do |result, commit|
      result["#{commit.author[:name]} <#{commit.author[:email]}>"] += 1
      result
    end
  rescue Rugged::ReferenceError
    {}
  rescue Rugged::OdbError
    {}
  end

  # Returns file meta data based on relative file path
  #
  # @example
  #  file_meta("path/to/file")
  #  => { :author => "Nick", :size => 1000, :modified => ... }
  #
  # @param [String] file relative path to file in repository
  #
  # @raise [RuntimeError] if the file is not found in any commits
  #
  # @return [Hash<Symbol=>String,Integer,Time>] the author, size and
  #   modification date of the file
  def file_meta(file)
    file = file.gsub(%r{^/}, '')

    commit = head_walker.find { |x| x.diff(paths: [file]).size > 0 }

    fail "File #{file} not found" unless commit

    full_path = File.expand_path(file, root)
    size = if File.directory?(full_path)
      Dir[File.join(full_path, '**', '*')].reduce(0) do |size, file|
        File.symlink?(file) ? size : size += File.size(file)
      end
    else
      File.symlink?(full_path) ? 0 : File.size(full_path)
    end
    size = -1 if size == 0 # A value of 0 breaks the table sort for some reason

    { author: commit.author[:name], size: size, modified: commit.author[:time] }
  end

  # Returns the revisions available for a particular file
  #
  # @example
  #   file_revisions("README")
  #
  # @param [String] file
  #
  # @return [Array<Hash>]
  def file_revisions(file)
    file = file.gsub(%r{^/}, '')
    # Excluding the initial commit (without a parent) which keeps things
    # consistent with the original behaviour.
    # TODO: reconsider if this is the correct behaviour
    head_walker.select{|x| x.parents.size == 1 && x.diff(paths: [file]).size > 0 }
      .first(100)
      .map do |commit|
        {
          commit:  commit.oid[0, 7],
          subject: commit.message.split("\n")[0],
          author:  commit.author[:name],
          date:    commit.author[:time]
        }
      end
  end

  # Put the contents of the specified file revision into a temporary file
  #
  # @example
  #   file_revision_at("README", "a4c56h")
  #   => "/tmp/some/path/README"
  #
  # @param [String] file
  # @param [String] ref
  #
  # @return [String] path of the temporary file
  def file_revision_at(file, ref)
    file = file.gsub(%r{^/}, '')
    content = @rugged.blob_at(ref, file).text
    tmp_path = File.expand_path(File.basename(file), Dir.tmpdir)
    File.open(tmp_path, 'w') { |f| f.puts content }
    tmp_path
  end

  # Revert file to the specified ref
  #
  # @param [String] file
  # @param [String] ref
  def file_revert(file, ref)
    file = file.gsub(%r{^/}, '')
    blob = @rugged.blob_at(ref, file)
    # Silently fail if the file/ref do not existing in the repository.
    # Which is consistent with the original behaviour.
    # TODO: should consider throwing an exception on this condition
    return unless blob

    File.open(File.expand_path(file, root), 'w') { |f| f.puts(blob.text) }
  end

  ##############################################################################

  private

  def has_remote?
    @rugged.remotes.any?
  end

  # HACK: This will return nil if there are no commits in the remote branch.
  # It is not the response that I would expect but it mostly gets the job
  # done. This should probably be reviewed when upgrading to the next version
  # of Rugged.
  #
  # @return [nil] if the remote branch does not exist
  # @return [Rugged::Remote]
  def remote_branch
    Rugged::Branch.lookup(@rugged, "#{@remote_name}/#{@branch_name}", :remote)
  end

  def head_walker
    walker = Rugged::Walker.new(@rugged)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(@rugged.head.target)
    walker
  end
end
