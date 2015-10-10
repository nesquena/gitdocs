# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Notifier do
  let(:notifier) { Gitdocs::Notifier.new(show_notifications) }

  describe '.error' do
    subject { Gitdocs::Notifier.error(:title, :message, :show_notification) }
    before do
      Gitdocs::Notifier.expects(:new).with(:show_notification)
        .returns(notifier = mock)
      notifier.expects(:error).with(:title, :message)
    end
    it { subject }
  end

  describe '#info' do
    subject { notifier.info('title', 'message') }

    before { Gitdocs.expects(:log_info).with('title: message') }

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

    before { Gitdocs.expects(:log_warn).with('title: message') }

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

    before { Gitdocs.expects(:log_error).with('title: message') }

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
end
