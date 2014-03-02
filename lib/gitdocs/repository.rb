# -*- encoding : utf-8 -*-

# Wrapper for accessing the shared git repositories.
# Rugged, grit, or shell will be used in that order of preference depending
# upon the features which are available with each option.
#
# @note If a repository is invalid then query methods will return nil, and
#   command methods will raise exceptions.
#
class Gitdocs::Repository
  include ShellTools
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

    @rugged         = Rugged::Repository.new(path)
    @invalid_reason = nil
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

  # @return [String] oid of the HEAD of the working directory
  def current_oid
    @rugged.head.target
  rescue Rugged::ReferenceError
    nil
  end

  # Fetch and merge the repository
  #
  # @raise [RuntimeError] if there is a problem processing conflicted files
  #
  # @return [nil] if the repository is invalid
  # @return [:no_remote] if the remote is not yet set
  # @return [String] if there is an error return the message
  # @return [Array<String>] if there is a conflict return the Array of
  #   conflicted file names
  # @return [:ok] if pulled and merged with no errors or conflicts
  def pull
    return nil unless valid?
    return :no_remote unless has_remote?

    out, status = sh_with_code("cd #{root} ; git fetch --all 2>/dev/null && git merge #{@remote_name}/#{@branch_name} 2>/dev/null")

    if status.success?
      :ok
    elsif out[/CONFLICT/]
      # Find the conflicted files
      conflicted_files = sh('git ls-files -u --full-name -z').split("\0")
        .reduce(Hash.new { |h, k| h[k] = [] }) do|h, line|
          parts = line.split(/\t/)
          h[parts.last] << parts.first.split(/ /)
          h
        end

      # Mark the conflicted files
      conflicted_files.each do |conflict, ids|
        conflict_start, conflict_end = conflict.scan(/(.*?)(|\.[^\.]+)$/).first
        ids.each do |(mode, sha, id)|
          author =  ' original' if id == '1'
          system("cd #{root} && git show :#{id}:#{conflict} > '#{conflict_start} (#{sha[0..6]}#{author})#{conflict_end}'")
        end
        system("cd #{root} && git rm --quiet #{conflict} >/dev/null 2>/dev/null") || fail
      end

      conflicted_files.keys
    else
      out # return the output on error
    end
  end

  # Commit and push the repository
  #
  # @return [nil] if the repository is invalid
  # @return [:no_remote] if the remote is not yet set
  # @return [:nothing] if there was nothing to do
  # @return [String] if there is an error return the message
  # @return [:ok] if commited and pushed without errors or conflicts
  def push(last_synced_oid, message='Auto-commit from gitdocs')
    return nil unless valid?
    return :no_remote unless has_remote?

    #add and commit
    sh_string('find . -type d -regex ``./[^.].*'' -empty -exec touch \'{}/.gitignore\' \;')
    sh_string('git add .')
    sh_string("git commit -a -m #{ShellTools.escape(message)}") unless sh("cd #{root} ; git status -s").empty?

    if last_synced_oid.nil? || sh_string('git status')[/branch is ahead/]
      out, code = sh_with_code("git push #{@remote_name} #{@branch_name}")
      if code.success?
        :ok
      elsif last_synced_oid.nil?
        :nothing
      elsif out[/\[rejected\]/]
        :conflict
      else
        out # return the output on error
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
    sh_string('git remote')
  end

  def head_walker
    walker = Rugged::Walker.new(@rugged)
    walker.sorting(Rugged::SORT_DATE)
    walker.push(@rugged.head.target)
    walker
  end

  # sh_string("git config branch.`git branch | grep '^\*' | sed -e 's/\* //'`.remote", "origin")
  def sh_string(cmd, default = nil)
    val = sh("cd #{root} ; #{cmd}").strip rescue nil
    val.nil? || val.empty? ? default : val
  end

  # Run in shell, return both status and output
  # @see #sh
  def sh_with_code(cmd)
    ShellTools.sh_with_code(cmd, root)
  end
end
