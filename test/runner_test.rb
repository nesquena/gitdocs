# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'gitdocs runner' do
  let(:runner) { Gitdocs::Runner.new(share) }

  let(:share)      { stub(polling_interval: 1, notification: true) }
  let(:notifier)   { stub }
  let(:repository) { stub(root: 'root_path') }
  before do
    Gitdocs::Notifier.stubs(:new).with(true).returns(notifier)
    Gitdocs::Repository.stubs(:new).with(share).returns(repository)
  end

  describe '#root' do
    subject { runner.root }
    it { subject.must_equal 'root_path' }
  end

  describe '#sync_changes' do
    subject { runner.sync_changes }

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
          notifier.expects(:merge_notification).with('error', 'root_path')
        end
        it { subject }
      end

      describe 'when merge not_ok' do
        let(:fetch_result) { :ok }
        before do
          repository.expects(:merge).returns(:not_ok)
          notifier.expects(:merge_notification).with(:not_ok, 'root_path')
          repository.expects(:push).returns(push_result)
        end

        describe 'and push is not_ok' do
          let(:push_result) { :not_ok }
          before { notifier.expects(:push_notification).with(:not_ok, 'root_path') }
          it { subject }
        end

        describe 'and push is ok' do
          let(:push_result) { :ok }
          before do
            runner.instance_variable_set(:@last_synced_revision, :oid)
            repository.stubs(:current_oid).returns(:next_oid)
            changes = { 'Alice' => 1, 'Bob' => 2 }
            repository.stubs(:author_count).with(:oid).returns(changes)
            notifier.expects(:push_notification).with(changes, 'root_path')
          end
          it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
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
          notifier.expects(:merge_notification).with(changes, 'root_path')
          repository.expects(:push).returns(push_result)
        end

        describe 'and push is not_ok' do
          let(:push_result) { :not_ok }
          before { notifier.expects(:push_notification).with(:not_ok, 'root_path') }
          it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :merge_oid }
        end

        describe 'and push is ok' do
          let(:push_result) { :ok }
          before do
            changes = { 'Charlie' => 5, 'Dan' =>  7 }
            repository.stubs(:author_count).with(:merge_oid).returns(changes)
            notifier.expects(:push_notification).with(changes, 'root_path')
          end
          it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :push_oid }
        end
      end
    end
  end
end
