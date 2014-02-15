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
      let(:path_or_share) { local_repo_path }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
    end

    describe 'with a share that is a repository' do
      let(:path_or_share) { stub(path: local_repo_path) }
      it { subject.must_be_kind_of Gitdocs::Repository }
      it { subject.valid?.must_equal true }
      it { subject.invalid_reason.must_be_nil }
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

  describe '#available_remotes' do
    subject { repository.available_remotes }

    describe 'when invalid' do
      let(:path_or_share) { 'tmp/unit/missing' }
      it { subject.must_be_nil }
    end

    describe 'when valid' do
      let(:path_or_share) { local_repo_path }
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
      let(:path_or_share) { local_repo_path }
      it { subject.must_equal [] }
    end
  end

  describe '#current_oid' do
    subject { repository.current_oid }
    let(:path_or_share) { local_repo_path }

    describe 'no commits' do
      it { subject.must_equal nil }
    end

    describe 'has commits' do
      before do
        File.write(File.join(local_repo_path, 'touch_me'), "")
        `cd #{local_repo_path} ; git add touch_me ; git commit -m 'commit' --author='#{author1}'`
        @head_oid = `cd #{local_repo_path} ; git rev-parse HEAD`.strip
      end
      it { subject.must_equal @head_oid }
    end
  end

  describe '#author_count' do
    subject { repository.author_count(last_oid) }

    let(:path_or_share) { local_repo_path }

    describe 'no commits' do
      let(:last_oid) { nil }
      it { subject.must_equal({}) }
    end

    describe 'commits' do
      before do
        File.write(File.join(local_repo_path, 'touch_me'), 'first')
        `cd #{local_repo_path} ; git add touch_me ; git commit -m 'initial commit' --author='#{author1}'`

        @intermediate_oid = `cd #{local_repo_path} ; git rev-parse HEAD`.strip

        File.write(File.join(local_repo_path, 'touch_me'), 'second')
        `cd #{local_repo_path} ; git commit -a -m 'commit' --author='#{author1}'`

        File.write(File.join(local_repo_path, 'touch_me'), 'third')
        `cd #{local_repo_path} ; git commit -a -m 'commit' --author='#{author2}'`

        File.write(File.join(local_repo_path, 'touch_me'), 'fourth')
        `cd #{local_repo_path} ; git commit -a -m 'commit' --author='#{author1}'`
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
end
