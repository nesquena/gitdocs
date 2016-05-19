# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::GitNotifier do
  let(:git_notifier) { Gitdocs::GitNotifier.new(:root, :show_notifications) }

  describe '.for_merge' do
    subject { git_notifier.for_merge(result) }

    describe 'with no changes' do
      before do
        # Ensure that the notification methods are not called.
        Gitdocs::Notifier.stubs(:warn).raises
        Gitdocs::Notifier.stubs(:info).raises
        Gitdocs::Notifier.stubs(:error).raises
      end
      describe('with nil')        { let(:result) { nil }        ; it { subject } }
      describe('with no_remote')  { let(:result) { :no_remote } ; it { subject } }
      describe('with no changes') { let(:result) { {} }         ; it { subject } }
    end

    describe 'with changes' do
      let(:result) { { 'Alice' => 1, 'Bob' => 3 } }
      before do
        Gitdocs::Notifier.expects(:info).with(
          'Updated with 4 changes',
          "In root:\n* Alice (1 change)\n* Bob (3 changes)",
          :show_notifications
        )
      end
      it { subject }
    end

    describe 'with conflicts' do
      let(:result) { ['file'] }
      before do
        Gitdocs::Notifier.expects(:warn).with(
          'There were some conflicts',
          '* file',
          :show_notifications
        )
      end
      it { subject }
    end

    describe 'with anything else' do
      let(:result) { 'error' }
      before do
        Gitdocs::Notifier.expects(:error).with(
          'There was a problem synchronizing this gitdoc',
          "A problem occurred in root:\nerror",
          :show_notifications
        )
      end
      it { subject }
    end
  end

  describe '.for_push' do
    subject { git_notifier.for_push(result) }

    describe 'with no changes' do
      before do
        # Ensure that the notification methods are not called.
        Gitdocs::Notifier.stubs(:warn).raises
        Gitdocs::Notifier.stubs(:info).raises
        Gitdocs::Notifier.stubs(:error).raises
      end
      describe('with nil')       { let(:result) { nil }        ; it { subject } }
      describe('with no_remote') { let(:result) { :no_remote } ; it { subject } }
      describe('with nothing')   { let(:result) { :nothing }   ; it { subject } }
    end

    describe 'with changes' do
      let(:result) { { 'Alice' => 1, 'Bob' => 3 } }
      before do
        Gitdocs::Notifier.expects(:info).with(
          'Pushed 4 changes', 'root has been pushed', :show_notifications
        )
      end
      it { subject }
    end

    describe 'with conflict' do
      let(:result) { :conflict }
      before do
        Gitdocs::Notifier.expects(:warn).with(
          'There was a conflict in root, retrying', '', :show_notifications
        )
      end
      it { subject }
    end

    describe 'with anything else' do
      let(:result) { 'error' }
      before do
        Gitdocs::Notifier.expects(:error).with(
          'BAD Could not push changes in root', 'error', :show_notifications
        )
      end
      it { subject }
    end
  end

  describe '.on_error' do
    subject { git_notifier.on_error(:exception) }
    before do
      Gitdocs::Notifier.expects(:error).with(
        'Unexpected error when fetching/pushing in root',
        'exception',
        :show_notifications
      )
    end
    it { subject }
  end
end
