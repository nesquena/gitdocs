# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::SyncronizationNotifier do
  describe '.notify' do
    subject { Gitdocs::SyncronizationNotifier.notify(:merge_result, :push_result, :share) }
    before do
      Gitdocs::SyncronizationNotifier.expects(:new)
        .with(:share)
        .returns(syncronization_notifier = mock)
      syncronization_notifier.expects(:merge_notify).with(:merge_result)
      syncronization_notifier.expects(:push_notify).with(:push_result)
    end

    it { subject }
  end

  describe 'instance methods' do
    let(:syncronization_notifier) { Gitdocs::SyncronizationNotifier.new(share) }
    let(:share)    { mock }
    let(:notifier) { mock }
    before do
      share.stubs(path: :path, notification: :notification)
      Gitdocs::Notifier.stubs(:new).with(:notification).returns(notifier)
    end

    describe '#merge_notify' do
      subject { syncronization_notifier.merge_notify(result) }

      describe 'with no changes' do
        before do
          # Ensure that the notification methods are not called.
          notifier.stubs(:warn).raises
          notifier.stubs(:info).raises
          notifier.stubs(:error).raises
        end
        describe('with nil')        { let(:result) { nil }        ; it { subject } }
        describe('with no_remote')  { let(:result) { :no_remote } ; it { subject } }
        describe('with no changes') { let(:result) { {} }         ; it { subject } }
      end

      describe 'with changes' do
        let(:result)  { { 'Alice' => 1, 'Bob' => 3 } }
        before do
          notifier.expects(:info).with(
            'Updated with 4 changes',
            "In path:\n* Alice (1 change)\n* Bob (3 changes)"
          )
        end
        it { subject }
      end

      describe 'with conflicts' do
        let(:result)  { ['file'] }
        before do
          notifier.expects(:warn).with(
            'There were some conflicts',
            '* file'
          )
        end
        it { subject }
      end

      describe 'with anything else' do
        let(:result) { 'error' }
        before do
          notifier.expects(:error).with(
            'There was a problem synchronizing this gitdoc',
            "A problem occurred in path:\nerror"
          )
        end
        it { subject }
      end
    end

    describe '#push_notify' do
      subject { syncronization_notifier.push_notify(result) }

      describe('with nil')       { let(:result) { nil }        ; it { subject } }
      describe('with no_remote') { let(:result) { :no_remote } ; it { subject } }
      describe('with nothing')   { let(:result) { :nothing }   ; it { subject } }

      describe 'with changes' do
        let(:result)  { { 'Alice' => 1, 'Bob' => 3 } }
        before do
          notifier.expects(:info)
            .with('Pushed 4 changes', 'path has been pushed')
        end
        it { subject }
      end

      describe 'with conflict' do
        let(:result) { :conflict }
        before do
          notifier.expects(:warn)
            .with('There was a conflict in path, retrying', '')
        end
        it { subject }
      end

      describe 'with anything else' do
        let(:result) { 'error' }
        before do
          notifier.expects(:error)
            .with('BAD Could not push changes in path', 'error')
        end
        it { subject }
      end
    end
  end
end
