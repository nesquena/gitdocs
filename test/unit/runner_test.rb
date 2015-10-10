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

    before { repository.expects(:valid?).returns(true) }

    describe 'fetch sync' do
      before do
        share.stubs(:sync_type).returns('fetch')
        repository.expects(:fetch).returns(fetch_result)
      end

      describe('fetch failure') { let(:fetch_result) { :not_ok } ; it { subject } }
      describe('fetch success') { let(:fetch_result) { :ok }     ; it { subject } }
    end

    describe 'full sync' do
      before do
        share.stubs(:sync_type).returns('full')
        repository.expects(:commit)
        repository.expects(:fetch).returns(fetch_result)
      end

      describe 'fetch failure' do
        let(:fetch_result) { :not_ok }
        it { subject }
      end

      describe 'when merge error' do
        let(:fetch_result) { :ok }
        before do
          repository.expects(:merge).returns('error')
          git_notifier.expects(:for_merge).with('error')
        end
        it { subject }
      end

      describe 'when merge not_ok' do
        let(:fetch_result) { :ok }
        before do
          repository.expects(:merge).returns(:not_ok)
          git_notifier.expects(:for_merge).with(:not_ok)
          repository.expects(:push).returns(push_result)
        end

        describe 'and push is not_ok' do
          let(:push_result) { :not_ok }
          before { git_notifier.expects(:for_push).with(:not_ok) }
          it { subject }
        end

        describe 'and push is ok' do
          let(:push_result) { :ok }
          before do
            runner.instance_variable_set(:@last_synced_revision, :oid)
            repository.stubs(:current_oid).returns(:next_oid)
            changes = { 'Alice' => 1, 'Bob' => 2 }
            repository.stubs(:author_count).with(:oid).returns(changes)
            git_notifier.expects(:for_push).with(changes)

            subject
          end
          it { runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
        end
      end

      describe 'merge ok' do
        let(:fetch_result) { :ok }

        before do
          repository.stubs(:current_oid).returns(:merge_oid, :push_oid)

          repository.expects(:merge).returns(:ok)
          runner.instance_variable_set(:@last_synced_revision, :oid)
          changes = { 'Alice' => 1, 'Bob' => 3 }
          repository.stubs(:author_count).with(:oid).returns(changes)
          git_notifier.expects(:for_merge).with(changes)
          repository.expects(:push).returns(push_result)
        end

        describe 'and push is not_ok' do
          let(:push_result) { :not_ok }
          before do
            git_notifier.expects(:for_push).with(:not_ok)

            subject
          end
          it { runner.instance_variable_get(:@last_synced_revision).must_equal :merge_oid }
        end

        describe 'and push is ok' do
          let(:push_result) { :ok }
          before do
            changes = { 'Charlie' => 5, 'Dan' =>  7 }
            repository.stubs(:author_count).with(:merge_oid).returns(changes)
            git_notifier.expects(:for_push).with(changes)

            subject
          end
          it { runner.instance_variable_get(:@last_synced_revision).must_equal :push_oid }
        end
      end
    end
  end
end
