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
    return :no_remote unless sh_string('git remote')

    out, status = sh_with_code("git fetch --all 2>/dev/null && git merge #{@remote_name}/#{@branch_name} 2>/dev/null")

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
      out #return the output on error
    end
  end

  # Get the count of commits by author from the head to the specified oid.
  #
  # @param [String] last_oid
  #
  # @return [Hash<String, Int>]
  def author_count(last_oid)
    walker = Rugged::Walker.new(@rugged)
    walker.push(@rugged.head.target)
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
  # file_meta("path/to/file")
  #  => { :author => "Nick", :size => 1000, :modified => ... }
  def file_meta(file)
    file = file.gsub(%r{^/}, '')
    full_path = File.expand_path(file, root)
    log_result = sh_string("git log --format='%aN|%ai' -n1 #{ShellTools.escape(file)}")
    author, modified = log_result.split('|')
    modified = Time.parse(modified.sub(' ', 'T')).utc.iso8601
    size = if File.directory?(full_path)
      Dir[File.join(full_path, '**', '*')].reduce(0) do |size, file|
        File.symlink?(file) ? size : size += File.size(file)
      end
    else
      File.symlink?(full_path) ? 0 : File.size(full_path)
    end
    size = -1 if size == 0 # A value of 0 breaks the table sort for some reason

    { author: author, size: size, modified: modified }
  end

  # Returns the revisions available for a particular file
  # file_revisions("README")
  def file_revisions(file)
    file = file.gsub(%r{^/}, '')
    output = sh_string("git log --format='%h|%s|%aN|%ai' -n100 #{ShellTools.escape(file)}")
    output.to_s.split("\n").map do |log_result|
      commit, subject, author, date = log_result.split('|')
      date = Time.parse(date.sub(' ', 'T')).utc.iso8601
      { commit: commit, subject: subject, author: author, date: date }
    end
  end

  # Returns the temporary path of a particular revision of a file
  # file_revision_at("README", "a4c56h") => "/tmp/some/path/README"
  def file_revision_at(file, ref)
    file = file.gsub(%r{^/}, '')
    content = sh_string("git show #{ref}:#{ShellTools.escape(file)}")
    tmp_path = File.expand_path(File.basename(file), Dir.tmpdir)
    File.open(tmp_path, 'w') { |f| f.puts content }
    tmp_path
  end

  def file_revert(file, ref)
    if file_revisions(file).map { |r| r[:commit] }.include? ref[0, 7]
      file = file.gsub(%r{^/}, '')
      full_path = File.expand_path(file, root)
      content = File.read(file_revision_at(file, ref))
      File.open(full_path, 'w') { |f| f.puts content }
    end
  end

  ##############################################################################

  private

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
