# -*- encoding : utf-8 -*-
class Gitdocs::Repository::Committer
  # @raise if the repository is not valid for commits
  def initialize(root_dirname)
    @root_dirname        = root_dirname
    @rugged              = Rugged::Repository.new(root_dirname)
    @grit                = Grit::Repo.new(root_dirname)
    @commit_message_path = File.expand_path('.gitmessage~', root_dirname)
  rescue Rugged::OSError
    raise(Gitdocs::Repository::InvalidError, 'No directory')
  rescue Rugged::RepositoryError
    raise(Gitdocs::Repository::InvalidError, 'Not a repository')
  end

  # @return [Boolean]
  def commit
    # Do this first to allow the message file to be deleted, if it exists.
    message = read_and_delete_commit_message_file

    mark_empty_directories

    # FIXME: Consider a more appropriate location for the dirty check.
    return false unless Gitdocs::Repository.new(@root_dirname).dirty?
    Gitdocs.log_debug("Repo #{@root_dirname} is dirty")

    # Commit any changes in the working directory.
    Dir.chdir(@root_dirname) do
      @rugged.index.add_all
      @rugged.index.update_all
    end
    @rugged.index.write
    Gitdocs.log_debug("Index to be committed #{@rugged.index}")

    commit_result = @grit.commit_index(message)
    Gitdocs.log_debug("Commit result: <#{commit_result.inspect}>")

    true
  end

  # @param [String] message
  # @return [void]
  def write_commit_message(message)
    return unless message
    return if message.empty?

    File.open(@commit_message_path, 'w') { |f| f.print(message) }
  end

  ##########################################################################

  private

  def mark_empty_directories
    Find.find(@root_dirname).each do |path| # rubocop:disable Style/Next
      Find.prune if File.basename(path) == '.git'
      if File.directory?(path) && Dir.entries(path).count == 2
        FileUtils.touch(File.join(path, '.gitignore'))
      end
    end
  end

  # @return [String] either the message in the file, or the regular
  #   automatic commit message.
  def read_and_delete_commit_message_file
    return 'Auto-commit from gitdocs' unless File.exist?(@commit_message_path)

    message = File.read(@commit_message_path)
    File.delete(@commit_message_path)
    message
  end
end
