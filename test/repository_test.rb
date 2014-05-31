# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository do
  let(:local_repo_path) { 'tmp/unit/local' }
  let(:author1)         { 'Art T. Fish <afish@example.com>' }
  let(:author2)         { 'A U Thor <author@example.com>' }

  before do
    FileUtils.rm_rf('tmp/unit')
    mkdir
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
        write_and_commit('file4', "foo\ndead\nbeef\nfoobar", 'commit', author1)
      end
      it do
        subject.must_equal([
          Gitdocs::Repository::SearchResult.new('file1', 'foo'),
          Gitdocs::Repository::SearchResult.new('file3', 'foobar'),
          Gitdocs::Repository::SearchResult.new('file4', 'foo ... foobar')
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

  describe '#fetch' do
    subject { repository.fetch }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'with remote' do
      before { create_local_repo_with_remote }

      describe 'and times out' do
        before do
          Grit::Repo.any_instance.stubs(:remote_fetch)
            .raises(Grit::Git::GitTimeout.new)
        end
        it { subject.must_equal "Fetch timed out for #{File.absolute_path(local_repo_path)}" }
      end

      describe 'and command fails' do
        before do
          Grit::Repo.any_instance.stubs(:remote_fetch)
            .raises(Grit::Git::CommandFailed.new('', 1, 'fetch error output'))
        end
        it { subject.must_equal 'fetch error output' }
      end

      describe 'and success' do
        before do
          bare_commit(
            remote_repo,
            'file1', 'deadbeef',
            'commit', 'author@example.com', 'A U Thor'
          )
        end
        it { subject.must_equal :ok }
        it { subject ; local_repo_remote_branch.tip.oid.wont_be_nil }
      end
    end
  end

  describe '#merge' do
    subject { repository.merge }

    let(:path_or_share) do
      stub(
        path:        local_repo_path,
        remote_name: 'origin',
        branch_name: 'master'
      )
    end

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'has remote but nothing to merge' do
      before { create_local_repo_with_remote }
      it { subject.must_equal :ok }
    end

    describe 'has remote and times out' do
      before do
        create_local_repo_with_remote
        bare_commit(
          remote_repo,
          'file1', 'deadbeef',
          'commit', 'author@example.com', 'A U Thor'
        )
        repository.fetch

        Grit::Git.any_instance.stubs(:merge)
          .raises(Grit::Git::GitTimeout.new)
      end
      it { subject.must_equal "Merge timed out for #{File.absolute_path(local_repo_path)}" }
    end

    describe 'and fails, but does not conflict' do
      before do
        create_local_repo_with_remote
        bare_commit(
          remote_repo,
          'file1', 'deadbeef',
          'commit', 'author@example.com', 'A U Thor'
        )
        repository.fetch

        Grit::Git.any_instance.stubs(:merge)
          .raises(Grit::Git::CommandFailed.new('', 1, 'merge error output'))
      end
      it { subject.must_equal 'merge error output' }
    end

    describe 'and there is a conflict' do
      before do
        create_local_repo_with_remote_with_commit
        bare_commit(
          remote_repo,
          'file1', 'dead',
          'second commit',
          'author@example.com', 'A U Thor'
        )
        write_and_commit('file1', 'beef', 'conflict commit', author1)
        repository.fetch
      end

      it { subject.must_equal ['file1'] }
      it { subject ; commit_count(local_repo).must_equal 2 }
      it { subject ; local_file_count.must_equal 3 }
      it { subject ; local_file_content('file1 (f6ea049 original)').must_equal 'foobar' }
      it { subject ; local_file_content('file1 (18ed963)').must_equal 'beef' }
      it { subject ; local_file_content('file1 (7bfce5c)').must_equal 'dead' }
    end

    describe 'and there is a conflict, with additional files' do
      before do
        create_local_repo_with_remote_with_commit
        bare_commit(
          remote_repo,
          'file1', 'dead',
          'second commit',
          'author@example.com', 'A U Thor'
        )
        bare_commit(
          remote_repo,
          'file2', 'foo',
          'second commit',
          'author@example.com', 'A U Thor'
        )
        write_and_commit('file1', 'beef', 'conflict commit', author1)
        repository.fetch
      end

      it { subject.must_equal ['file1'] }
      it { subject ; commit_count(local_repo).must_equal 2 }
      it { subject ; local_file_count.must_equal 3 }
      it { subject ; local_file_content('file1 (f6ea049 original)').must_equal 'foobar' }
      it { subject ; local_file_content('file1 (18ed963)').must_equal 'beef' }
      it { subject ; local_file_content('file2').must_equal 'foo' }
    end

    describe 'and there are non-conflicted local commits' do
      before do
        create_local_repo_with_remote_with_commit
        write_and_commit('file1', 'beef', 'conflict commit', author1)
        repository.fetch
      end
      it { subject.must_equal :ok }
      it { subject ; local_file_count.must_equal 1 }
      it { subject ; commit_count(local_repo).must_equal 2 }
    end

      describe 'when new remote commits are merged' do
        before do
          create_local_repo_with_remote_with_commit
          bare_commit(
            remote_repo,
            'file2', 'deadbeef',
            'second commit',
            'author@example.com', 'A U Thor'
          )
          repository.fetch
        end
        it { subject.must_equal :ok }
        it { subject ; local_file_exist?('file2').must_equal true }
        it { subject ; commit_count(local_repo).must_equal 2 }
      end
  end

  describe '#commit' do
    subject { repository.commit('message') }

    let(:path_or_share) { stub(
      path:        local_repo_path,
      remote_name: 'origin',
      branch_name: 'master'
    ) }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'no previous commits' do
      describe 'nothing to commit' do
        it { subject.must_equal false }
      end

      describe 'changes to commit' do
        before do
          write('file1', 'foobar')
          mkdir('directory')
        end
        it { subject.must_equal true }
        it { subject ; local_file_exist?('directory/.gitignore').must_equal true }
        it { subject ; commit_count(local_repo).must_equal 1 }
        it { subject ; head_commit(local_repo).message.must_equal "message\n" }
        it { subject ; local_repo_clean?.must_equal true }
      end
    end

    describe 'previous commits' do
      before do
        write_and_commit('file1', 'foobar', 'initial commit', author1)
        write_and_commit('file2', 'deadbeef', 'second commit', author1)
      end

      describe 'nothing to commit' do
        it { subject.must_equal false }
      end

      describe 'changes to commit' do
        before do
          write('file1', 'foobar')
          FileUtils.rm_rf(File.join(local_repo_path, 'file2'))
          write('file3', 'foobar')
          mkdir('directory')
        end
        it { subject.must_equal true }
        it { subject ; local_file_exist?('directory/.gitignore').must_equal true }
        it { subject ; commit_count(local_repo).must_equal 3 }
        it { subject ; head_commit(local_repo).message.must_equal "message\n" }
        it { subject ; local_repo_clean?.must_equal true }
      end
    end
  end

  describe '#push' do
    subject { repository.push }

    let(:path_or_share) { stub(
      path:        local_repo_path,
      remote_name: 'origin',
      branch_name: 'master'
    ) }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'remote exists with no commits' do
      before { create_local_repo_with_remote }

      describe 'and no local commits' do
        it { subject.must_equal :nothing }
        it { subject ; commit_count(remote_repo).must_equal 0 }
      end

      describe 'and a local commit' do
        before { write_and_commit('file2', 'foobar', 'commit', author1) }

        describe 'and the push fails' do
          # Simulate an error occurring during the push
          before do
            Grit::Git.any_instance.stubs(:push)
              .raises(Grit::Git::CommandFailed.new('', 1, 'error message'))
          end
          it { subject.must_equal 'error message' }
        end

        describe 'and the push succeeds' do
          it { subject.must_equal :ok }
          it { subject ; commit_count(remote_repo).must_equal 1 }
        end
      end
    end

    describe 'remote exists with commits' do
      before { create_local_repo_with_remote_with_commit }

      describe 'and no local commits' do
        it { subject.must_equal :nothing }
        it { subject ; commit_count(remote_repo).must_equal 1 }
      end

      describe 'and a local commit' do
        before { write_and_commit('file2', 'foobar', 'commit', author1) }

        describe 'and the push fails' do
          # Simulate an error occurring during the push
          before do
            Grit::Git.any_instance.stubs(:push)
              .raises(Grit::Git::CommandFailed.new('', 1, 'error message'))
          end
          it { subject.must_equal 'error message' }
        end

        describe 'and the push conflicts' do
          before { bare_commit(remote_repo, 'file2', 'dead', 'commit', 'A U Thor', 'author@example.com') }

          it { subject ; commit_count(remote_repo).must_equal 2 }
          it { subject.must_equal :conflict }
        end

        describe 'and the push succeeds' do
          it { subject.must_equal :ok }
          it { subject ; commit_count(remote_repo).must_equal 2 }
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
      it { subject ; local_file_content('directory', 'file2').must_equal 'beef' }
    end

    describe 'file does include the revision' do
      let(:ref) { @commit2 }
      it { subject ; local_file_content('directory', 'file2').must_equal "bar\n" }
    end
  end

  ##############################################################################

  private
  def create_local_repo_with_remote
    FileUtils.rm_rf(local_repo_path)
    repo = Rugged::Repository.clone_at(remote_repo.path, local_repo_path)
    repo.config['user.email'] = 'afish@example.com'
    repo.config['user.name']  = 'Art T. Fish'
  end

  def create_local_repo_with_remote_with_commit
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

  def mkdir(*path)
    FileUtils.mkdir_p(File.join(local_repo_path, *path))
  end

  def write(filename, content)
    mkdir(File.dirname(filename))
    File.write(File.join(local_repo_path, filename), content)
  end

  def write_and_commit(filename, content, commit_msg, author)
    mkdir(File.dirname(filename))
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
  rescue Rugged::ReferenceError
    # The repo does not have a head => no commits.
    0
  end

  def head_commit(repo)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target)
    walker.first
  rescue Rugged::ReferenceError
    # The repo does not have a head => no commits => no head commit.
    nil
  end

  def head_tree_files(repo)
    head_commit(repo).tree.map { |x| x[:name] }
  end

  # NOTE: This method is ignoring hidden files.
  def local_file_count
    files = Dir.chdir(local_repo_path) { Dir.glob('*') }
    files.count
  end

  def local_repo_remote_branch
    Rugged::Branch.lookup(local_repo, 'origin/master', :remote)
  end

  def local_repo_clean?
    local_repo.diff_workdir(local_repo.head.target, include_untracked: true).deltas.empty?
  end

  def local_file_exist?(*path_elements)
    File.exist?(File.join(local_repo_path, *path_elements))
  end

  def local_file_content(*path_elements)
    return nil unless local_file_exist?
    File.read(File.join(local_repo_path, *path_elements))
  end
end
