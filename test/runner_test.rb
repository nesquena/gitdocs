require File.expand_path('../test_helper', __FILE__)

describe 'gitdocs runner' do
  let(:runner) { Gitdocs::Runner.new(share)}

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

    before { repository.expects(:pull).returns(pull_result) }

    describe 'when invalid' do
      let(:pull_result) { nil }
      it { subject.must_equal nil }
    end

    describe 'when no remote present' do
      let(:pull_result) { :no_remote }
      it { subject.must_equal nil }
    end

    describe 'when merge is conflicted' do
      let(:pull_result) { ['file'] }
      before do
        notifier.expects(:warn).with(
          'There were some conflicts',
          "* file"
        )
        runner.expects(:push_changes)
      end
      it { subject.must_equal nil }
    end

    describe 'when merge is ok' do
      let(:pull_result) { :ok }
      before do
        runner.instance_variable_set(:@last_synced_revision, :oid)
        repository.stubs(:current_oid).returns(:next_oid)
        repository.stubs(:author_count).with(:oid).returns('Alice' => 1, 'Bob' => 2)
        notifier.expects(:info).with(
          'Updated with 3 changes',
          "In 'root_path':\n* Alice (1 change)\n* Bob (2 changes)"
        )
        runner.expects(:push_changes)
      end
      it { subject.must_equal nil }
      it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
    end
  end

  describe '#push_changes' do
    subject { runner.push_changes }

    before { repository.expects(:push).returns(push_result) }

    describe 'when invalid' do
      let(:push_result) { nil }
      it { subject.must_equal nil }
    end

    describe 'when no remote present' do
      let(:push_result) { :no_remote }
      it { subject.must_equal nil }
    end

    describe 'when nothing happened' do
      let(:push_result) { :nothing }
      it { subject.must_equal nil }
    end

    describe 'when there is an error' do
      let(:push_result) { 'error' }
      before do
        notifier.expects(:error)
          .with('BAD Could not push changes in root_path', 'error')
      end
      it { subject.must_equal nil }
    end

    describe 'when push is conflicted' do
      let(:push_result) { :conflict }
      before do
        notifier.expects(:warn)
          .with('There was a conflict in root_path, retrying', '')
      end
      it { subject.must_equal nil }
    end

    describe 'when merge is ok' do
      let(:push_result) { :ok }
      before do
        runner.instance_variable_set(:@last_synced_revision, :oid)
        repository.stubs(:current_oid).returns(:next_oid)
        repository.stubs(:author_count).with(:oid).returns('Alice' => 1, 'Bob' => 2)
        notifier.expects(:info)
          .with('Pushed 3 changes', "'root_path' has been pushed")
      end
      it { subject.must_equal nil }
      it { subject ; runner.instance_variable_get(:@last_synced_revision).must_equal :next_oid }
    end
  end
end
