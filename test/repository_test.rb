# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Repository do
  let(:local_repo_path) { 'tmp/unit/local' }
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
end
