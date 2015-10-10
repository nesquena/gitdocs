# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository::Committer do
  before do
    FileUtils.rm_rf('tmp/unit')
    GitFactory.init(:local)
  end

  let(:root_dirname) { GitFactory.expand_path(:local) }
  let(:committer)    { Gitdocs::Repository::Committer.new(root_dirname) }

  describe 'initialize' do
    subject { committer }

    describe 'when directory missing' do
      let(:root_dirname) { GitFactory.expand_path(:missing) }
      it { assert_raises(Gitdocs::Repository::InvalidError) { subject } }
    end

    describe 'when not a repository' do
      let(:root_dirname) { GitFactory.expand_path(:not_a_repo) }
      before { FileUtils.mkdir_p(root_dirname) }
      it { assert_raises(Gitdocs::Repository::InvalidError) { subject } }
    end

    describe 'when valid repository' do
      it { subject.must_be_kind_of Gitdocs::Repository::Committer }
    end
  end

  describe '#commit' do
    subject { committer.commit }

    before { Gitdocs.stubs(:log_debug) }

    # TODO: should test the paths which use the message file

    describe 'no previous commits' do
      describe 'nothing to commit' do
        it { subject.must_equal false }
      end

      describe 'changes to commit' do
        before do
          GitFactory.write(:local, 'file1', 'foobar')
          GitFactory.mkdir(:local, 'directory')
        end
        it { subject.must_equal true }

        describe 'side effects' do
          before { subject }
          it { GitInspector.file_exist?(:local, 'directory/.gitignore').must_equal true }
          it { GitInspector.commit_count(:local).must_equal 1 }
          it { GitInspector.last_message(:local).must_equal "Auto-commit from gitdocs\n" }
          it { GitInspector.clean?(:local).must_equal true }
        end
      end
    end

    describe 'previous commits' do
      before do
        GitFactory.commit(:local, 'file1', 'foobar')
        GitFactory.commit(:local, 'file2', 'deadbeef')
      end

      describe 'nothing to commit' do
        it { subject.must_equal false }
      end

      describe 'changes to commit' do
        before do
          GitFactory.write(:local, 'file1', 'foobar')
          GitFactory.rm(:local, 'file2')
          GitFactory.write(:local, 'file3', 'foobar')
          GitFactory.mkdir(:local, 'directory')
        end
        it { subject.must_equal true }

        describe 'side effects' do
          before { subject }
          it { GitInspector.file_exist?(:local, 'directory/.gitignore').must_equal true }
          it { GitInspector.commit_count(:local).must_equal 3 }
          it { GitInspector.last_message(:local).must_equal "Auto-commit from gitdocs\n" }
          it { GitInspector.clean?(:local).must_equal true }
        end
      end
    end
  end

  describe '#write_commit_message' do
    subject { result = committer.write_commit_message(commit_message) ; puts result; result}

    before { subject }

    describe 'with no message' do
      let(:commit_message) { nil }
      it { GitInspector.file_exist?(:local, '.gitmessage~').must_equal(false) }
    end

    describe 'with empty message' do
      let(:commit_message) { '' }
      it { GitInspector.file_exist?(:local, '.gitmessage~').must_equal(false) }
    end

    describe 'with message' do
      let(:commit_message) { 'foobar' }
      it { GitInspector.file_content(:local, '.gitmessage~').must_equal('foobar') }
    end
  end
end
