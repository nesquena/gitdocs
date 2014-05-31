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

    before do
      repository.stubs(:fetch).returns(fetch_result)
      repository.stubs(:merge).returns(merge_result)
    end

    describe 'when nothing to fetch' do
      let(:fetch_result) { :not_ok }
      let(:merge_result) { nil }
      it { subject }
    end

    describe 'when merge error' do
      let(:fetch_result) { :ok }
      let(:merge_result) { 'error' }
      before { notifier.expects(:merge_notification).with('error', 'root_path') }
      it { subject }
    end

    describe 'when merge not_ok' do
      let(:fetch_result) { :ok }
      let(:merge_result) { :not_ok }
      before do
        notifier.expects(:merge_notification).with(:not_ok, 'root_path')
        runner.expects(:push_changes)
      end
      it { subject }
    end

    describe 'when merge is ok' do
      let(:fetch_result) { :ok }
      let(:merge_result) { :ok }
      before do
        runner.instance_variable_set(:@last_synced_revision, :oid)
        repository.stubs(:current_oid).returns(:next_oid)
        changes = { 'Alice' => 1, 'Bob' => 2 }
        repository.stubs(:author_count).with(:oid).returns(changes)

        notifier.expects(:merge_notification).with(changes, 'root_path')
        runner.expects(:push_changes)
      end
      it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
    end
  end

  describe '#push_changes' do
    subject { runner.push_changes }

    before do
      repository.expects(:commit)
        .with('Auto-commit from gitdocs')
        .returns(push_result)
      repository.expects(:push)
        .returns(push_result)
    end

    describe 'when push not_ok' do
      let(:push_result) { :not_ok }
      before { notifier.expects(:push_notification).with(:not_ok, 'root_path') }
      it { subject }
    end

    describe 'when push is ok' do
      let(:push_result) { :ok }
      before do
        runner.instance_variable_set(:@last_synced_revision, :oid)
        repository.stubs(:current_oid)
          .returns(:next_oid)
        changes = { 'Alice' => 1, 'Bob' => 2 }
        repository.stubs(:author_count).with(:oid).returns(changes)
        notifier.expects(:push_notification).with(changes, 'root_path')
      end
      it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
    end
  end
end
