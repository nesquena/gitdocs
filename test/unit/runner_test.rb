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
      repository.expects(:valid?).returns(true)
      share.stubs(:sync_type).returns(sync_type)
    end

    describe 'fetch sync' do
      let(:sync_type) { 'fetch' }

      describe('fetch failure') do
        before { repository.expects(:fetch).raises(Gitdocs::Repository::FetchError) }
        it { subject }
      end

      describe('fetch success') do
        before { repository.expects(:fetch) }
        it { subject }
      end
    end

    describe 'full sync' do
      let(:sync_type) { 'full' }

      before { repository.expects(:commit) }

      describe 'with fetch failure' do
        before { repository.expects(:fetch).raises(Gitdocs::Repository::FetchError) }
        it { subject }
      end

      describe 'when merge error' do
        before do
          repository.expects(:fetch)
          repository.expects(:merge).raises(Gitdocs::Repository::MergeError, 'error')
          git_notifier.expects(:for_merge).with('error')
        end
        it { subject }
      end

      describe 'when merge ok' do
        let(:fetch_result) { :ok }

        before do
          repository.expects(:fetch)
          repository.expects(:merge).returns(:merge_result)
          git_notifier.expects(:for_merge).with(:merge_result)

          repository.expects(:push).returns(:push_result)
          git_notifier.expects(:for_push).with(:push_result)
        end

        it { subject }
      end
    end
  end
end
