# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository do
  let(:local_repo_path) { 'tmp/unit/local' }
  let(:author1)         { 'Art T. Fish <afish@example.com>' }
  let(:author2)         { 'A U Thor <author@example.com>' }

  before do
    FileUtils.rm_rf('tmp/unit')
    FileUtils.mkdir_p(local_repo_path)
    repo = Rugged::Repository.init_at(local_repo_path)
    repo.config['user.email'] = 'afish@example.com'
    repo.config['user.name']  = 'Art T. Fish'
  end

  let(:repository) { Gitdocs::Repository.new(path_or_share) }
  # Default path for the repository object, which can be overridden by the
  # tests when necessary.
  let(:path_or_share) { local_repo_path }
  let(:remote_repo)   { Rugged::Repository.init_at('tmp/unit/remote', :bare) }
  let(:local_repo)    { Rugged::Repository.new(local_repo_path) }


  describe 'initialize' do
    subject { repository }

    describe 'with a missing path' do
      let(:path_or_share) { 'tmp/unit/missing_path' }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal false }
      it { subject.invalid_reason.must_equal :directory_missing }
    end

    describe 'with a path that is not a repository' do
      let(:path_or_share) { 'tmp/unit/not_a_repo' }
      before { FileUtils.mkdir_p(path_or_share) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal false }
      it { subject.invalid_reason.must_equal :no_repository }
    end

    describe 'with a string path that is a repository' do
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
      it { subject.instance_variable_get(:@rugged).wont_be_nil }
      it { subject.instance_variable_get(:@grit).wont_be_nil }
    end

    describe 'with a share that is a repository' do
      let(:path_or_share) { stub(
        path:        local_repo_path,
        remote_name: 'remote',
        branch_name: 'branch'
      ) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
      it { subject.instance_variable_get(:@rugged).wont_be_nil }
      it { subject.instance_variable_get(:@grit).wont_be_nil }
      it { subject.instance_variable_get(:@branch_name).must_equal 'branch' }
      it { subject.instance_variable_get(:@remote_name).must_equal 'remote' }
    end
  end

  describe '.clone' do
    subject { Gitdocs::Repository.clone(path, remote) }

    let(:path)   { 'tmp/unit/clone' }
    let(:remote) { 'tmp/unit/remote' }

    describe 'with invalid remote' do
      it { assert_raises(RuntimeError) { subject } }
    end

    describe 'with valid remote' do
      before { Rugged::Repository.init_at(remote, :bare) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
    end
  end

  describe '.search' do
    subject { Gitdocs::Repository.search('term', repositories) }

    let(:repositories) { Array.new(4, stub(root: 'root')) }
    before do
      repositories[0].expects(:search).with('term').returns(:result1)
      repositories[1].expects(:search).with('term').returns(:result2)
      repositories[2].expects(:search).with('term').returns(:result3)
      repositories[3].expects(:search).with('term').returns([])
    end

    it do
      subject.must_equal({
        Gitdocs::Repository::RepoDescriptor.new('root', 1) => :result3,
        Gitdocs::Repository::RepoDescriptor.new('root', 2) => :result2,
        Gitdocs::Repository::RepoDescriptor.new('root', 3) => :result1
      })
    end
  end

  describe '#search' do
    subject { repository.search(term) }

    describe 'empty term' do
      let(:term) { '' }
      it { subject.must_equal [] }
    end

    describe 'nothing found' do
      let(:term) { 'foo' }
      before do
        write_and_commit('file1', 'bar', 'commit', author1)
        write_and_commit('file2', 'beef', 'commit', author1)
      end
      it { subject.must_equal [] }
    end


    describe 'term found' do
      let(:term) { 'foo' }
      before do
        write_and_commit('file1', 'foo', 'commit', author1)
        write_and_commit('file2', 'beef', 'commit', author1)
        write_and_commit('file3', 'foobar', 'commit', author1)
      end
      it do
        subject.must_equal([
          Gitdocs::Repository::SearchResult.new('file1', 'foo'),
          Gitdocs::Repository::SearchResult.new('file3', 'foobar')
        ])
      end
    end
  end

  describe '#root' do
    subject { repository.root }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      it { subject.must_equal File.expand_path(local_repo_path) }
    end
  end

  describe '#available_remotes' do
    subject { repository.available_remotes }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      it { subject.must_equal [] }
    end
  end

  describe '#available_branches' do
    subject { repository.available_branches }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      it { subject.must_equal [] }
    end
  end

  describe '#current_oid' do
    subject { repository.current_oid }

    describe 'no commits' do
      it { subject.must_equal nil }
    end

    describe 'has commits' do
      before { @head_oid = write_and_commit('touch_me', '', 'commit', author1) }
      it { subject.must_equal @head_oid }
    end
  end

  describe '#pull' do
    subject { repository.pull }

    let(:path_or_share) { stub(
      path:        local_repo_path,
      remote_name: 'origin',
      branch_name: 'master'
    ) }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when there is no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'when there is an error' do
      before do
        Rugged::Remote.add(
            Rugged::Repository.new(local_repo_path),
            'origin',
            'file:///bad/remote'
        )
      end
      it { subject.must_equal "Fetching origin\n" }
    end

    describe 'with a valid remote' do
      before { create_local_repo_with_remote }

      describe 'when there is nothing to pull' do
        it { subject.must_equal :ok }
      end

      describe 'when there is a conflict' do
        before do
          bare_commit(
            remote_repo,
            'file1', 'dead',
            'second commit',
            'author@example.com', 'A U Thor'
          )
          write_and_commit('file1', 'beef', 'conflict commit', author1)
        end

        it { subject.must_equal ['file1'] }
        it { subject ; commit_count(local_repo).must_equal 2 }
        it { subject ; local_repo_files.count.must_equal 3 }
        it { subject ; local_repo_files.must_include 'file1 (f6ea049 original)' }
        it { subject ; local_repo_files.must_include 'file1 (18ed963)' }
        it { subject ; local_repo_files.must_include 'file1 (7bfce5c)' }
      end

      describe 'when new commits are pulled and merged' do
        before do
          bare_commit(
            remote_repo,
            'file2', 'deadbeef',
            'second commit',
            'author@example.com', 'A U Thor'
          )
        end
        it { subject.must_equal :ok }
        it { subject ; File.exists?(File.join(local_repo_path, 'file2')).must_equal true }
        it { subject ; commit_count(local_repo).must_equal 2 }
      end
    end
  end

  describe '#push' do
    subject { repository.push(last_oid, 'message') }

    let(:path_or_share) { stub(
      path:        local_repo_path,
      remote_name: 'origin',
      branch_name: 'master'
    ) }

    describe 'when invalid' do
      let(:last_oid)      { nil }
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      let(:last_oid) { nil }
      it { subject.must_equal :no_remote }
    end

    describe 'remote exists' do
      before { create_local_repo_with_remote }

      describe 'last sync is nil' do
        let(:last_oid) { nil }

        describe 'and there is an error on push' do
          # Simulate an error occurring during the push
          before do
            Grit::Git.any_instance.stubs(:push).raises(
              Grit::Git::CommandFailed.new('', 1, '')
            )
          end
          it { subject.must_equal :nothing }
        end

        describe 'and there is a conflicted file to push' do
          before do
            bare_commit(remote_repo, 'file1', 'dead', 'commit', 'A U Thor', 'author@example.com')
            write('file1', 'beef')
          end
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject.must_equal :nothing }
        end

        describe 'and there is an empty directory to push' do
          before { FileUtils.mkdir_p(File.join(local_repo_path, 'directory')) }
          it { subject.must_equal :ok }
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject ; head_commit(remote_repo).message.must_equal "message\n" }
          it { subject ; head_tree_files(remote_repo).count.must_equal 2 }
          it { subject ; head_tree_files(remote_repo).must_include 'file1' }
          it { subject ; head_tree_files(remote_repo).must_include 'directory' }
        end

        describe 'and there is an existing file update to push' do
          before { write('file1', 'deadbeef') }
          it { subject.must_equal :ok }
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject ; head_commit(remote_repo).message.must_equal "message\n" }
          it { subject ; head_tree_files(remote_repo).count.must_equal 1 }
          it { subject ; head_tree_files(remote_repo).must_include 'file1' }
        end

        describe 'and there is a new file to push' do
          before { write('file2', 'foobar') }
          it { subject.must_equal :ok }
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject ; head_commit(remote_repo).message.must_equal "message\n" }
          it { subject ; head_tree_files(remote_repo).count.must_equal 2 }
          it { subject ; head_tree_files(remote_repo).must_include 'file1' }
          it { subject ; head_tree_files(remote_repo).must_include 'file2' }
        end
      end

      describe 'last sync is not nil' do
        let(:last_oid) { 'oid' }

        describe 'and this is an error on the push' do
          before do
            write('file2', 'foobar')

            # Simulate an error occurring during the push
            Grit::Git.any_instance.stubs(:push).raises(
              Grit::Git::CommandFailed.new('', 1, 'error message')
            )
          end
          it { subject.must_equal 'error message' }
        end

        describe 'and this is nothing to push' do
          it { subject.must_equal :nothing }
        end

        describe 'and there is a conflicted commit to push' do
          before do
            bare_commit(remote_repo, 'file1', 'dead', 'commit', 'A U Thor', 'author@example.com')
            write('file1', 'beef')
          end
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject.must_equal :conflict }
        end

        describe 'and there is a commit to push' do
          before { write('file2', 'foobar') }
          it { subject.must_equal :ok }
          it { subject ; commit_count(local_repo).must_equal 2 }
          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject ; head_commit(remote_repo).message.must_equal "message\n" }
          it { subject ; head_tree_files(remote_repo).count.must_equal 2 }
          it { subject ; head_tree_files(remote_repo).must_include 'file1' }
          it { subject ; head_tree_files(remote_repo).must_include 'file2' }
        end
      end
    end
  end

  describe '#author_count' do
    subject { repository.author_count(last_oid) }

    describe 'no commits' do
      let(:last_oid) { nil }
      it { subject.must_equal({}) }
    end

    describe 'commits' do
      before do
        @intermediate_oid = write_and_commit('touch_me', 'first', 'initial commit', author1)
        write_and_commit('touch_me', 'second', 'commit', author1)
        write_and_commit('touch_me', 'third', 'commit', author2)
        write_and_commit('touch_me', 'fourth', 'commit', author1)
      end

      describe 'all' do
        let(:last_oid) { nil }
        it { subject.must_equal({ author1 => 3, author2 => 1 }) }
      end

      describe 'some' do
        let(:last_oid) { @intermediate_oid }
        it { subject.must_equal({ author1 => 2, author2 => 1 }) }
      end

      describe 'missing oid' do
        let(:last_oid) { 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'  }
        it { subject.must_equal({}) }
      end
    end
  end

  describe '#file_meta' do
    subject { repository.file_meta(file_name) }

    before do
      write_and_commit('directory0/file0', '', 'initial commit', author1)
      write_and_commit('directory/file1', 'foo', 'commit1', author1)
      write_and_commit('directory/file2', 'bar', 'commit2', author2)
      write_and_commit('directory/file2', 'beef', 'commit3', author2)
    end

    describe 'on a missing file' do
      let(:file_name) { 'missing_file' }
      it { assert_raises(RuntimeError) { subject } }
    end

    describe 'on a file' do
      describe 'of size zero' do
        let(:file_name) { 'directory0/file0' }
        it { subject[:author].must_equal 'Art T. Fish' }
        it { subject[:size].must_equal -1 }
        it { subject[:modified].wont_be_nil }
      end

      describe 'of non-zero size' do
        let(:file_name) { 'directory/file1' }
        it { subject[:author].must_equal 'Art T. Fish' }
        it { subject[:size].must_equal 3 }
        it { subject[:modified].wont_be_nil }
      end
    end

    describe 'on a directory' do
      describe 'of size zero' do
        let(:file_name) { 'directory0' }
        it { subject[:author].must_equal 'Art T. Fish' }
        it { subject[:size].must_equal -1 }
        it { subject[:modified].wont_be_nil }
      end

      describe 'of non-zero size' do
        let(:file_name) { 'directory' }
        it { subject[:author].must_equal 'A U Thor' }
        it { subject[:size].must_equal 7 }
        it { subject[:modified].wont_be_nil }
      end
    end
  end

  describe '#file_revisions' do
    subject { repository.file_revisions('directory') }

    before do
      write_and_commit('directory0/file0', '', 'initial commit', author1)
      @commit1 = write_and_commit('directory/file1', 'foo', 'commit1', author1)
      @commit2 = write_and_commit('directory/file2', 'bar', 'commit2', author2)
      @commit3 = write_and_commit('directory/file2', 'beef', 'commit3', author2)
    end

    it { subject.length.must_equal 3 }
    it { subject.map { |x| x[:author] }.must_equal ['A U Thor', 'A U Thor', 'Art T. Fish'] }
    it { subject.map { |x| x[:commit] }.must_equal [@commit3[0, 7], @commit2[0, 7], @commit1[0, 7]] }
    it { subject.map { |x| x[:subject] }.must_equal ['commit3', 'commit2', 'commit1'] }
  end

  describe '#file_revision_at' do
    subject { repository.file_revision_at('directory/file2', @commit) }

    before do
      write_and_commit('directory0/file0', '', 'initial commit', author1)
      write_and_commit('directory/file1', 'foo', 'commit1', author1)
      write_and_commit('directory/file2', 'bar', 'commit2', author2)
      @commit = write_and_commit('directory/file2', 'beef', 'commit3', author2)
    end

    it { subject.must_equal '/tmp/file2' }
    it { File.read(subject).must_equal "beef\n" }
  end

  describe '#file_revert' do
    subject { repository.file_revert('directory/file2', ref) }

    let(:file_name) { File.join(local_repo_path, 'directory', 'file2') }

    before do
      @commit0 = write_and_commit('directory0/file0', '', 'initial commit', author1)
      write_and_commit('directory/file1', 'foo', 'commit1', author1)
      @commit2 = write_and_commit('directory/file2', 'bar', 'commit2', author2)
      write_and_commit('directory/file2', 'beef', 'commit3', author2)
    end

    describe 'file does not include the revision' do
      let(:ref) { @commit0 }
      it { subject ; File.read(file_name).must_equal 'beef' }
    end

    describe 'file does include the revision' do
      let(:ref) { @commit2 }
      it { subject ; File.read(file_name).must_equal "bar\n" }
    end
  end

  ##############################################################################

  private

  def create_local_repo_with_remote
    bare_commit(
      remote_repo,
      'file1', 'foobar',
      'initial commit',
      'author@example.com', 'A U Thor'
    )
    FileUtils.rm_rf(local_repo_path)
    repo = Rugged::Repository.clone_at(remote_repo.path, local_repo_path)
    repo.config['user.email'] = 'afish@example.com'
    repo.config['user.name']  = 'Art T. Fish'
  end

  def write(filename, content)
    FileUtils.mkdir_p(File.join(local_repo_path, File.dirname(filename)))
    File.write(File.join(local_repo_path, filename), content)
  end

  def write_and_commit(filename, content, commit_msg, author)
    FileUtils.mkdir_p(File.join(local_repo_path, File.dirname(filename)))
    File.write(File.join(local_repo_path, filename), content)
    `cd #{local_repo_path} ; git add #{filename}; git commit -m '#{commit_msg}' --author='#{author}'`
    `cd #{local_repo_path} ; git rev-parse HEAD`.strip
  end

  def bare_commit(repo, filename, content, message, email, name)
    index = Rugged::Index.new
    index.add(
      path: filename,
      oid:  repo.write(content, :blob),
      mode: 0100644
    )

    Rugged::Commit.create(remote_repo, {
      tree:       index.write_tree(repo),
      author:     { email: email, name: name, time: Time.now },
      committer:  { email: email, name: name, time: Time.now },
      message:    message,
      parents:    repo.empty? ? [] : [ repo.head.target ].compact,
      update_ref: 'HEAD'
    })
  end

  def commit_count(repo)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target)
    walker.count
  end

  def head_commit(repo)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target)
    walker.first
  end

  def head_tree_files(repo)
    head_commit(repo).tree.map { |x| x[:name] }
  end

  def local_repo_files
    Dir.chdir(local_repo_path) do
      Dir.glob('*')
    end
  end
end
