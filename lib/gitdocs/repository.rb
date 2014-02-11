# -*- encoding : utf-8 -*-

# Wrapper for accessing the shared git repositories.
# Rugged, grit, or shell will be used in that order of preference depending
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
end
