# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository do
  before do
    FileUtils.rm_rf(GitFactory.working_directory)
    GitFactory.init(:local)
    GitFactory.init_bare(:remote)
  end

  let(:repository) { Gitdocs::Repository.new(path_or_share) }
  # Default Share for the repository object, which can be overridden by the
  # tests when necessary.
  let(:path_or_share) do
    stub(
      path:        expand_path(:local),
      remote_name: 'origin',
      branch_name: 'master'
    )
  end

  describe 'initialize' do
    subject { repository }

    describe 'with a missing path' do
      let(:path_or_share) { expand_path(:missing) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal false }
      it { subject.invalid_reason.must_equal :directory_missing }
    end

    describe 'with a path that is not a repository' do
      let(:path_or_share) { expand_path(:not_a_repo) }
      before { FileUtils.mkdir_p(path_or_share) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal false }
      it { subject.invalid_reason.must_equal :no_repository }
    end

    describe 'with a string path that is a repository' do
      let(:path_or_share) { expand_path(:local) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
      it { subject.instance_variable_get(:@rugged).wont_be_nil }
      it { subject.instance_variable_get(:@grit).wont_be_nil }
    end

    describe 'with a share that is a repository' do
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
      it { subject.instance_variable_get(:@rugged).wont_be_nil }
      it { subject.instance_variable_get(:@grit).wont_be_nil }
      it { subject.instance_variable_get(:@remote_name).must_equal 'origin' }
      it { subject.instance_variable_get(:@branch_name).must_equal 'master' }
    end
  end

  describe '.clone' do
    subject { Gitdocs::Repository.clone('tmp/unit/clone', remote) }

    describe 'with invalid remote' do
      let(:remote) { expand_path(:invalid) }
      it { assert_raises(RuntimeError) { subject } }
    end

    describe 'with valid remote' do
      let(:remote) { expand_path(:remote) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
    end
  end

  describe '#root' do
    subject { repository.root }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      it { subject.must_equal expand_path(:local) }
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
      before { @head_oid = commit('touch_me', '') }
      it { subject.must_equal @head_oid }
    end
  end

  describe '#dirty?' do
    subject { repository.dirty? }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_equal false }
    end

    describe 'when no existing commits' do
      describe 'and no new files' do
        it { subject.must_equal false }
      end

      describe 'and new files' do
        before { write('file1', 'foobar') }
        it { subject.must_equal true }
      end

      describe 'and new empty directory' do
        before { GitFactory.mkdir(:local, 'directory') }
        it { subject.must_equal true }
      end
    end

    describe 'when commits exist' do
      before { commit('file1', 'foobar') }

      describe 'and no changes' do
        it { subject.must_equal false }
      end

      describe 'add empty directory' do
        before { GitFactory.mkdir(:local, 'directory') }
        it { subject.must_equal false }
      end

      describe 'add file' do
        before { write('file2', 'foobar') }
        it { subject.must_equal true }
      end

      describe 'modify existing file' do
        before { write('file1', 'deadbeef') }
        it { subject.must_equal true }
      end

      describe 'delete file' do
        before { GitFactory.rm(:local, 'file1') }
        it { subject.must_equal true }
      end
    end
  end

  describe '#need_sync' do
    subject { repository.need_sync? }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_equal false }
    end

    describe 'when no remotes' do
      it { subject.must_equal false }
    end

    describe 'when no remote commits' do
      before { clone_remote }

      describe 'no local commits' do
        it { subject.must_equal false }
      end

      describe 'local commits' do
        before { commit('file1', 'beef') }
        it { subject.must_equal true }
      end
    end

    describe 'when remote commits' do
      before { clone_remote_with_commit }

      describe 'no local commits' do
        it { subject.must_equal false }
      end

      describe 'new local commit' do
        before { commit('file2', 'beef') }
        it { subject.must_equal true }
      end

      describe 'new remote commit' do
        before do
          bare_commit('file3', 'dead')
          repository.fetch
        end

        it { subject.must_equal true }
      end

      describe 'new local and remote commit' do
        before do
          bare_commit('file3', 'dead')
          repository.fetch
          commit('file4', 'beef')
        end

        it { subject.must_equal true }
      end
    end
  end

  describe '#grep' do
    subject { repository.grep('foo') { |file, context| @grep_result << "#{file} #{context}" } }

    before { @grep_result = [] }

    describe 'timeout' do
      before do
        Grit::Repo.any_instance.stubs(:remote_fetch)
          .raises(Grit::Git::GitTimeout.new)
      end
      it { subject ; @grep_result.must_equal([]) }
      it { subject.must_equal '' }
    end

    describe 'command failure' do
      before do
        Grit::Repo.any_instance.stubs(:remote_fetch)
          .raises(Grit::Git::CommandFailed.new('', 1, 'grep error output'))
      end
      it { subject ; @grep_result.must_equal([]) }
      it { subject.must_equal '' }
    end

    describe 'success' do
      before do
        commit('file1', 'foo')
        commit('file2', 'beef')
        commit('file3', 'foobar')
        commit('file4', "foo\ndead\nbeef\nfoobar")
      end
      it { subject ; @grep_result.must_equal(['file1 foo', 'file3 foobar', 'file4 foo', 'file4 foobar']) }
      it { subject.must_equal("file1:foo\nfile3:foobar\nfile4:foo\nfile4:foobar\n") }
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
      before { clone_remote }

      describe 'and times out' do
        before do
          Grit::Repo.any_instance.stubs(:remote_fetch)
            .raises(Grit::Git::GitTimeout.new)
        end
        it { subject.must_equal "Fetch timed out for #{expand_path(:local)}" }
      end

      describe 'and command fails' do
        before do
          Grit::Repo.any_instance.stubs(:remote_fetch)
            .raises(Grit::Git::CommandFailed.new('', 1, 'fetch error output'))
        end
        it { subject.must_equal 'fetch error output' }
      end

      describe 'and success' do
        before { bare_commit('file1', 'deadbeef') }
        it { subject.must_equal :ok }

        describe 'side effects' do
          before { subject }
          it { GitInspector.remote_oid(:local).wont_be_nil }
        end
      end
    end
  end

  describe '#merge' do
    subject { repository.merge }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'has remote but nothing to merge' do
      before { clone_remote }
      it { subject.must_equal :ok }
    end

    describe 'has remote and times out' do
      before do
        clone_remote
        bare_commit('file1', 'deadbeef')
        repository.fetch

        Grit::Git.any_instance.stubs(:merge)
          .raises(Grit::Git::GitTimeout.new)
      end
      it { subject.must_equal "Merge timed out for #{expand_path(:local)}" }
    end

    describe 'and fails, but does not conflict' do
      before do
        clone_remote
        bare_commit('file1', 'deadbeef')
        repository.fetch

        Grit::Git.any_instance.stubs(:merge)
          .raises(Grit::Git::CommandFailed.new('', 1, 'merge error output'))
      end
      it { subject.must_equal 'merge error output' }
    end

    describe 'and there is a conflict' do
      before do
        clone_remote_with_commit
        bare_commit('file1', 'dead')
        commit('file1', 'beef')
        repository.fetch
      end

      it { subject.must_equal ['file1'] }

      describe 'side effects' do
        before { subject }
        it { GitInspector.commit_count(:local).must_equal 2 }
        it { GitInspector.file_count(:local).must_equal 3 }
        it { GitInspector.file_content(:local, 'file1 (f6ea049 original)').must_equal 'foobar' }
        it { GitInspector.file_content(:local, 'file1 (18ed963)').must_equal 'beef' }
        it { GitInspector.file_content(:local, 'file1 (7bfce5c)').must_equal 'dead' }
      end
    end

    describe 'and there is a conflict, with additional files' do
      before do
        clone_remote_with_commit
        bare_commit('file1', 'dead')
        bare_commit('file2', 'foo')
        commit('file1', 'beef')
        repository.fetch
      end

      it { subject.must_equal ['file1'] }

      describe 'side effects' do
        before { subject }
        it { GitInspector.commit_count(:local).must_equal 2 }
        it { GitInspector.file_count(:local).must_equal 3 }
        it { GitInspector.file_content(:local, 'file1 (f6ea049 original)').must_equal 'foobar' }
        it { GitInspector.file_content(:local, 'file1 (18ed963)').must_equal 'beef' }
        it { GitInspector.file_content(:local, 'file2').must_equal 'foo' }
      end
    end

    describe 'and there are non-conflicted local commits' do
      before do
        clone_remote_with_commit
        commit('file1', 'beef')
        repository.fetch
      end
      it { subject.must_equal :ok }

      describe 'side effects' do
        before { subject }
        it { GitInspector.file_count(:local).must_equal 1 }
        it { GitInspector.commit_count(:local).must_equal 2 }
      end
    end

    describe 'when new remote commits are merged' do
      before do
        clone_remote_with_commit
        bare_commit('file2', 'deadbeef')
        repository.fetch
      end
      it { subject.must_equal :ok }

      describe 'side effects' do
        before { subject }
        it { GitInspector.file_exist?(:local, 'file2').must_equal true }
        it { GitInspector.commit_count(:local).must_equal 2 }
      end
    end
  end

  describe '#commit' do
    subject { repository.commit }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      before do
        Gitdocs::Repository::Committer.expects(:new).returns(committer = mock)
        committer.expects(:commit).returns(:result)
      end
      it { subject.must_equal(:result) }
    end
  end

  describe '#push' do
    subject { repository.push }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when no remote' do
      it { subject.must_equal :no_remote }
    end

    describe 'remote exists with no commits' do
      before { clone_remote }

      describe 'and no local commits' do
        it { subject.must_equal :nothing }

        describe 'side effects' do
          before { subject }
          it { GitInspector.commit_count(:remote).must_equal 0 }
        end
      end

      describe 'and a local commit' do
        before { commit('file2', 'foobar') }

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

          describe 'side effects' do
            before { subject }
            it { GitInspector.commit_count(:remote).must_equal 1 }
          end
        end
      end
    end

    describe 'remote exists with commits' do
      before { clone_remote_with_commit }

      describe 'and no local commits' do
        it { subject.must_equal :nothing }

        describe 'side effects' do
          before { subject }
          it { GitInspector.commit_count(:remote).must_equal 1 }
        end
      end

      describe 'and a local commit' do
        before { commit('file2', 'foobar') }

        describe 'and the push fails' do
          # Simulate an error occurring during the push
          before do
            Grit::Git.any_instance.stubs(:push)
              .raises(Grit::Git::CommandFailed.new('', 1, 'error message'))
          end
          it { subject.must_equal 'error message' }
        end

        describe 'and the push conflicts' do
          before { bare_commit('file2', 'dead') }

          it { subject.must_equal :conflict }

          describe 'side effects' do
            before { subject }
            it { GitInspector.commit_count(:remote).must_equal 2 }
          end
        end

        describe 'and the push succeeds' do
          it { subject.must_equal :ok }

          describe 'side effects' do
            before { subject }
            it { GitInspector.commit_count(:remote).must_equal 2 }
          end
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
        @intermediate_oid = commit('touch_me', 'first', 0)
        commit('touch_me', 'second', 0)
        commit('touch_me', 'third', 1)
        commit('touch_me', 'fourth', 0)
      end

      describe 'all' do
        let(:last_oid) { nil }
        it { subject.must_equal(GitFactory.authors[0] => 3, GitFactory.authors[1] => 1) }
      end

      describe 'some' do
        let(:last_oid) { @intermediate_oid }
        it { subject.must_equal(GitFactory.authors[0] => 2, GitFactory.authors[1] => 1) }
      end

      describe 'missing oid' do
        let(:last_oid) { 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'  }
        it { subject.must_equal({}) }
      end
    end
  end

  describe '#write_commit_message' do
    subject { repository.write_commit_message(:message) }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      before do
        Gitdocs::Repository::Committer.expects(:new).returns(committer = mock)
        committer.expects(:write_commit_message).with(:message).returns(:result)
      end
      it { subject.must_equal(:result) }
    end
  end

  describe '#commits_for' do
    subject { repository.commits_for('directory/file', 2) }

    before do
      commit('directory0/file0', '', 0)
      commit('directory/file', 'foo', 0)
      @commit2 = commit('directory/file', 'bar', 1)
      @commit3 = commit('directory/file', 'beef', 1)
    end

    it { subject.map(&:oid).must_equal([@commit3, @commit2]) }
  end

  describe '#last_commit_for' do
    subject { repository.last_commit_for('directory/file') }

    before do
      commit('directory/file', 'foo', 0)
      commit('directory/file', 'bar', 1)
      @commit3 = commit('directory/file', 'beef', 1)
    end

    it { subject.oid.must_equal(@commit3) }
  end

  describe '#blob_at' do
    subject { repository.blob_at('directory/file', @commit) }

    before do
      commit('directory/file', 'foo')
      @commit = commit('directory/file', 'bar', 1)
      commit('directory/file', 'beef', 1)
    end

    it { subject.text.must_equal('bar') }
  end

  ##############################################################################

  private

  # @param (see GitFactory.expand_path)
  # @return [String]
  def expand_path(*args)
    GitFactory.expand_path(*args)
  end

  # @return (see GitFactory.clone)
  def clone_remote
    GitFactory.clone(:remote, 'local')
  end

  # @return (see GitFactory.clone)
  def clone_remote_with_commit
    bare_commit('file1', 'foobar')
    clone_remote
  end

  # @param [String] filename
  # @param [String] content
  #
  # @return [void]
  def write(filename, content)
    GitFactory.write(:local, filename, content)
  end

  # @param (see GitFactory.commit)
  # @return (see GitFactory.commit)
  def commit(*args)
    GitFactory.commit(:local, *args)
  end

  # @param (see GitFactory.bare_commit)
  # @return (see GitFactory.bare_commit)
  def bare_commit(*args)
    GitFactory.bare_commit(:remote, *args)
  end
end
