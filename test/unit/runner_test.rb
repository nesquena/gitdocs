# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'gitdocs runner' do
  let(:runner) { Gitdocs::Runner.new(share) }

  let(:share) do
    stub(polling_interval: 1, path: 'root_path', notification: :notification)
  end
  let(:repository)   { stub(root: 'root_path') }
  let(:git_notifier) { stub }
  before do
    Gitdocs::Repository.expects(:new).with(share).returns(repository)
    Gitdocs::GitNotifier.expects(:new)
      .with('root_path', :notification)
      .returns(git_notifier)
  end

  describe '#root' do
    subject { runner.root }
    it { subject.must_equal 'root_path' }
  end

  describe '#sync_changes' do
    subject { runner.sync_changes }

    before do
      repository.expects(:valid?).returns(valid)
      share.stubs(:sync_type).returns(:sync_type)
    end

    describe 'invalid repostory' do
      let(:valid) { false }
      it { subject.must_equal(nil) }
    end

    describe 'valid repository with error' do
      let(:valid) { true }
      before do
        repository.expects(:synchronize)
          .with(:sync_type)
          .raises(error = StandardError.new)
        git_notifier.expects(:on_error).with(error).returns(:results)
      end
      it { subject.must_equal(:results) }
    end

    describe 'valid repository' do
      let(:valid) { true }
      before do
        repository.expects(:synchronize).with(:sync_type)
          .returns(merge: :merge, push: :push)
        git_notifier.expects(:for_merge).with(:merge)
        git_notifier.expects(:for_push).with(:push).returns(:result)
      end
      it { subject.must_equal(:result) }
    end
  end
end
