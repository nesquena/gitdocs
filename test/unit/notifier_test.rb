# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Notifier do
  describe 'public methods' do
    let(:notifier) { mock }
    before { Gitdocs::Notifier.stubs(:instance).returns(notifier) }

    describe '.info' do
      subject { Gitdocs::Notifier.info('title', 'message', show_notification) }

      before { Gitdocs.expects(:log_info).with('title: message') }

      describe 'without notifications' do
        let(:show_notification) { false }
        before { Gitdocs::Notifier.expects(:puts).with('title: message') }
        it { subject }
      end

      describe 'with notifications' do
        let(:show_notification) { true }
        before { notifier.expects(:notify).with('title', 'message', :success) }
        it { subject }
      end
    end

    describe '.warn' do
      subject { Gitdocs::Notifier.warn('title', 'message', show_notification) }

      before { Gitdocs.expects(:log_warn).with('title: message') }

      describe 'without notifications' do
        let(:show_notification) { false }
        before { Kernel.expects(:warn).with('title: message') }
        it { subject }
      end

      describe 'with notifications' do
        let(:show_notification) { true }
        before { notifier.expects(:notify).with('title', 'message', :pending) }
        it { subject }
      end
    end

    describe '.error' do
      subject { Gitdocs::Notifier.error('title', 'message', show_notification) }

      before { Gitdocs.expects(:log_error).with('title: message') }

      describe 'without notifications' do
        let(:show_notification) { false }
        before { Kernel.expects(:warn).with('title: message') }
        it { subject }
      end

      describe 'with notifications' do
        let(:show_notification) { true }
        before { notifier.expects(:notify).with('title', 'message', :failed) }
        it { subject }
      end
    end

    describe '.disconnect' do
      subject { Gitdocs::Notifier.disconnect }
      before { notifier.expects(:disconnect) }
      it { subject }
    end
  end

  describe 'private-ish instance methods' do
    let(:notifier)  { Gitdocs::Notifier.send(:new) }
    let(:notiffany) { mock }

    describe '#notify' do
      subject { notifier.notify(:title, :message, :type) }
      before do
        Notiffany.expects(:connect).returns(notiffany)
        notiffany.expects(:notify).with(:message, title: :title, image: :type)
      end
      it { subject }
    end

    describe '#disconnect' do
      subject { notifier.disconnect }

      describe 'not connected' do
        before do
          notifier.instance_variable_set(:@notifier, nil)
          subject
        end
        it { notifier.instance_variable_get(:@notifier).must_equal(nil) }
      end

      describe 'connect' do
        before do
          notifier.instance_variable_set(:@notifier, notiffany)
          notiffany.expects(:disconnect)
          subject
        end
        it { notifier.instance_variable_get(:@notifier).must_equal(nil) }
      end
    end
  end
end
