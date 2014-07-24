# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Notifier do
  let(:notifier) { Gitdocs::Notifier.new(show_notifications) }

  describe '#error' do
    subject { Gitdocs::Notifier.error(:title, :message) }
    before do
      Gitdocs::Notifier.expects(:new).with(true).returns(notifier = mock)
      notifier.expects(:error).with(:title, :message)
    end
    it { subject }
  end

  describe '#info' do
    subject { notifier.info('title', 'message') }

    describe 'without notifications' do
      let(:show_notifications) { false }
      before { notifier.expects(:puts).with('title: message') }
      it { subject }
    end

    describe 'with notifications' do
      let(:show_notifications) { true }
      before do
        Guard::Notifier.expects(:turn_on)
        Guard::Notifier.expects(:notify)
          .with(
            'message',
            title: 'title',
            image: File.expand_path('../../../lib/img/icon.png', __FILE__)
          )
      end
      it { subject }
    end
  end

  describe '#warn' do
    subject { notifier.warn('title', 'message') }

    describe 'without notifications' do
      let(:show_notifications) { false }
      before { Kernel.expects(:warn).with('title: message') }
      it { subject }
    end

    describe 'with notifications' do
      let(:show_notifications) { true }
      before do
        Guard::Notifier.expects(:turn_on)
        Guard::Notifier.expects(:notify).with('message', title: 'title')
      end
      it { subject }
    end
  end

  describe '#error' do
    subject { notifier.error('title', 'message') }

    describe 'without notifications' do
      let(:show_notifications) { false }
      before { Kernel.expects(:warn).with('title: message') }
      it { subject }
    end

    describe 'with notifications' do
      let(:show_notifications) { true }
      before do
        Guard::Notifier.expects(:turn_on)
        Guard::Notifier.expects(:notify).with('message', title: 'title', image: :failure)
      end
      it { subject }
    end
  end

  describe '#merge_notification' do
    subject { notifier.merge_notification(result, 'root_path') }

    let(:show_notifications) { false }

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
          "In root_path:\n* Alice (1 change)\n* Bob (3 changes)"
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
          "A problem occurred in root_path:\nerror"
        )
      end
      it { subject }
    end
  end

  describe '#push_notification' do
    subject { notifier.push_notification(result, 'root_path') }

    let(:show_notifications) { false }

    describe('with nil')       { let(:result) { nil }        ; it { subject } }
    describe('with no_remote') { let(:result) { :no_remote } ; it { subject } }
    describe('with nothing')   { let(:result) { :nothing }   ; it { subject } }

    describe 'with changes' do
      let(:result)  { { 'Alice' => 1, 'Bob' => 3 } }
      before do
        notifier.expects(:info)
          .with('Pushed 4 changes', 'root_path has been pushed')
      end
      it { subject }
    end

    describe 'with conflict' do
      let(:result) { :conflict }
      before do
        notifier.expects(:warn)
          .with('There was a conflict in root_path, retrying', '')
      end
      it { subject }
    end

    describe 'with anything else' do
      let(:result) { 'error' }
      before do
        notifier.expects(:error)
          .with('BAD Could not push changes in root_path', 'error')
      end
      it { subject }
    end
  end
end
