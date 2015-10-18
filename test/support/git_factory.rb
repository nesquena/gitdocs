require 'rugged'

module GitFactory
  class << self
    attr_accessor :working_directory

    def configure
      yield self
    end

    # @return [Array<Hash>]
    def users
      [
        { name: 'Art T. Fish', email: 'afish@example.com' },
        { name: 'A U Thor',    email: 'author@example.com' }
      ]
    end

    # @return [Array<String>]
    def authors
      users.map { |x| "#{x[:name]} <#{x[:email]}>" }
    end

    # @param [#to_s] repo_name
    #
    # @return [String]
    def expand_path(repo_name, *filename_path)
      File.expand_path(File.join(
        working_directory, repo_name.to_s, *filename_path
      ))
    end

    # @param [#to_s] repo_name
    #
    # @return [Rugged::Repository]
    def rugged_repository(repo_name)
      Rugged::Repository.new(expand_path(repo_name))
    end

    # @param [#to_s] repo_name
    #
    # @return [String]
    def init(repo_name)
      repository_path = expand_path(repo_name)

      FileUtils.rm_rf(repository_path)
      FileUtils.mkdir_p(File.dirname(repository_path))

      repo = Rugged::Repository.init_at(repository_path)
      repo.config['user.email'] = users[0][:email]
      repo.config['user.name']  = users[0][:name]

      repository_path
    end

    # @param [#to_s] repo_name
    #
    # @return [String]
    def init_bare(repo_name)
      repository_path = expand_path(repo_name)

      FileUtils.rm_rf(repository_path)
      FileUtils.mkdir_p(File.dirname(repository_path))

      repo = Rugged::Repository.init_at(repository_path, :bare)
      repo.config['user.email'] = users[0][:email]
      repo.config['user.name']  = users[0][:name]

      repository_path
    end

    # @param [#to_s] bare_repo_name
    # @param [#to_s] repo_name
    #
    # @return [String]
    def clone(bare_repo_name, repo_name)
      bare_repository_path = expand_path(bare_repo_name)
      repository_path      = expand_path(repo_name)

      # assert bare_repository_path is a valid bare repository
      FileUtils.rm_rf(repository_path)

      repo = Rugged::Repository.clone_at(
        bare_repository_path, repository_path
      )
      repo.config['user.email'] = users[0][:email]
      repo.config['user.name']  = users[0][:name]

      repository_path
    end

    # @param [#to_s] repo_name
    # @param [String] directory_name
    #
    # @return [void]
    def mkdir(repo_name, directory_name)
      directory_path = expand_path(repo_name, directory_name)
      FileUtils.mkdir_p(directory_path)
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    # @param [String] content
    #
    # @return [void]
    def write(repo_name, filename, content)
      file_path = expand_path(repo_name, filename)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.write(file_path, content)
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    # @param [String] content
    #
    # @return [void]
    def append(repo_name, filename, content)
      file_path = expand_path(repo_name, filename)
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'a') { |f| f << content }
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    #
    # @return [void]
    def rm(repo_name, filename)
      file_path = expand_path(repo_name, filename)
      FileUtils.rm_rf(file_path)
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    # @param [String] content
    # @param [String] author_id
    #
    # @return [void]
    def commit(repo_name, filename, content, author_id = 0)
      commit_message = 'commit'
      write(repo_name, filename, content)

      repository_path = expand_path(repo_name)
      `cd #{repository_path} ; git add #{filename}; git commit -m '#{commit_message}' --author='#{authors[author_id]}'`
      `cd #{repository_path} ; git rev-parse HEAD`.strip
    end

    # @overload bare_commit(repo_name, filename, content)
    #   @param [#to_s] repo_name
    #   @param [String] filename
    #   @param [String] content
    #
    # @overload  bare_commit(repo_name, filename, content, author_id)
    #   @param [#to_s] repo_name
    #   @param [String] filename
    #   @param [String] content
    #   @param [String] author_id
    #
    # @return [void]
    def bare_commit(repo_name, filename, content, author_id = 0)
      commit_message = 'commit'
      repo = rugged_repository(repo_name)

      index = Rugged::Index.new
      index.add(
        path: filename,
        oid:  repo.write(content, :blob),
        mode: 0100644
      )

      author_hash = {
        email: users[author_id][:email],
        name:  users[author_id][:name],
        time:  Time.now
      }

      Rugged::Commit.create(
        repo,
        tree:       index.write_tree(repo),
        author:     author_hash,
        committer:  author_hash,
        message:    commit_message,
        parents:    repo.empty? ? [] : [repo.head.target].compact,
        update_ref: 'HEAD'
      )
    end
  end
end

module GitInspector
  class << self
    # @param [#to_s] repo_name
    #
    # @return [Integer]
    def commit_count(repo_name)
      repo = GitFactory.rugged_repository(repo_name)
      walker = Rugged::Walker.new(repo)
      walker.push(repo.head.target)
      walker.count
    rescue Rugged::ReferenceError
      # The repo does not have a head => no commits.
      0
    end

    # @param [to_s] repo_name
    #
    # @return [Boolean]
    def clean?(repo_name)
      repo = GitFactory.rugged_repository(repo_name)
      repo.diff_workdir(
        repo.head.target, include_untracked: true
      ).deltas.empty?
    rescue Rugged::Error
      false
    end

    # @param [#to_s] repo_name
    #
    # @return [String]
    def remote_oid(repo_name)
      repo = GitFactory.rugged_repository(repo_name)
      Rugged::Branch.lookup(repo, 'origin/master', :remote).tip.oid
    end

    # @param [#to_s] repo_name
    #
    # @return [nil]
    # @return [String]
    def last_message(repo_name)
      repo = GitFactory.rugged_repository(repo_name)
      walker = Rugged::Walker.new(repo)
      walker.push(repo.head.target)
      commit = walker.first
      return unless commit
      commit.message
    rescue Rugged::ReferenceError
      # The repo does not have a head => no commits => no head commit.
      nil
    end

    # NOTE: This method is ignoring hidden files.
    # @param [#to_s] repo_name
    #
    # @return [Integer]
    def file_count(repo_name)
      repository_path = GitFactory.expand_path(repo_name)
      files = Dir.chdir(repository_path) { Dir.glob('*') }
      files.count
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    #
    # @return [String]
    def file_exist?(repo_name, filename)
      file_path = GitFactory.expand_path(repo_name, filename)
      File.exist?(file_path)
    end

    # @param [#to_s] repo_name
    # @param [String] filename
    #
    # @return [nil]
    # @return [String]
    def file_content(repo_name, filename)
      return unless file_exist?(repo_name, filename)
      file_path = GitFactory.expand_path(repo_name, filename)
      File.read(file_path)
    end
  end
end

GitFactory.configure do |config|
  config.working_directory = Dir.tmpdir
end
