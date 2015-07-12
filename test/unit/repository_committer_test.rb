# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository::Committer do

  before do
    FileUtils.rm_rf('tmp/unit')
#    mkdir
#    repo = Rugged::Repository.init_at('tmp/unit/local')
#    repo.config['user.email'] = 'afish@example.com'
#    repo.config['user.name']  = 'Art T. Fish'
  end

  let(:root_dirname) { 'tmp/unit/local' }
  let(:committer)    { Gitdocs::Repository::Committer.new(root_dirname) }
  let(:local_repo)   { Rugged::Repository.new(root_dirname) }
  let(:author1)      { 'Art T. Fish <afish@example.com>' }

  describe 'initialize' do
    subject { committer }

    describe 'when directory missing' do
      it { assert_raises(Gitdocs::Repository::InvalidError) { subject } }
    end

    describe 'when not a repository' do
      before { mkdir }
      it { assert_raises(Gitdocs::Repository::InvalidError) { subject } }
    end

    describe 'when valid repository' do
      before { init_at }
      it { subject.must_be_kind_of Gitdocs::Repository::Committer }
    end
  end

  describe '#commit' do
    subject { committer.commit }
    before { init_at }

    # TODO: should test the paths which use the message file

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

        describe 'side effects' do
          before { subject }
          it { local_file_exist?('directory/.gitignore').must_equal true }
          it { commit_count(local_repo).must_equal 1 }
          it { head_commit(local_repo).message.must_equal "Auto-commit from gitdocs\n" }
          it { local_repo_clean?.must_equal true }
        end
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
          rm_rf('file2')
          write('file3', 'foobar')
          mkdir('directory')
        end
        it { subject.must_equal true }

        describe 'side effects' do
          before { subject }
          it { local_file_exist?('directory/.gitignore').must_equal true }
          it { commit_count(local_repo).must_equal 3 }
          it { head_commit(local_repo).message.must_equal "Auto-commit from gitdocs\n" }
          it { local_repo_clean?.must_equal true }
        end
      end
    end
  end

  describe '#write_commit_message' do
    subject { result = committer.write_commit_message(commit_message) ; puts result; result}

    before do
      init_at
      subject
    end

    describe 'with no message' do
      let(:commit_message) { nil }
      it { local_file_exist?('.gitmessage~').must_equal(false) }
    end

    describe 'with empty message' do
      let(:commit_message) { '' }
      it { local_file_exist?('.gitmessage~').must_equal(false) }
    end

    describe 'with message' do
      let(:commit_message) { 'foobar' }
      it { local_file_content('.gitmessage~').must_equal('foobar') }
    end
  end

  ##############################################################################

  private

  def rm_rf(filename)
    FileUtils.rm_rf(File.join(root_dirname, filename))
  end

  def init_at
    mkdir
    repo = Rugged::Repository.init_at(root_dirname)
    repo.config['user.email'] = 'afish@example.com'
    repo.config['user.name']  = 'Art T. Fish'
  end

  def mkdir(*path)
    FileUtils.mkdir_p(File.join(root_dirname, *path))
  end

  def write(filename, content)
    mkdir(File.dirname(filename))
    File.write(File.join(root_dirname, filename), content)
  end

  def local_file_exist?(*path_elements)
    File.exist?(File.join(root_dirname, *path_elements))
  end

  def head_commit(repo)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target)
    walker.first
  rescue Rugged::ReferenceError
    # The repo does not have a head => no commits => no head commit.
    nil
  end

  def commit_count(repo)
    walker = Rugged::Walker.new(repo)
    walker.push(repo.head.target)
    walker.count
  rescue Rugged::ReferenceError
    # The repo does not have a head => no commits.
    0
  end

  def local_repo_clean?
    local_repo.diff_workdir(local_repo.head.target, include_untracked: true).deltas.empty?
  end

  def local_file_content(*path_elements)
    return nil unless local_file_exist?
    File.read(File.join(root_dirname, *path_elements))
  end

  # @return [String] commit oid
  def write_and_commit(filename, content, commit_msg, author)
    mkdir(File.dirname(filename))
    File.write(File.join(root_dirname, filename), content)
    `cd #{root_dirname} ; git add #{filename}; git commit -m '#{commit_msg}' --author='#{author}'`
    `cd #{root_dirname} ; git rev-parse HEAD`.strip
  end
end
