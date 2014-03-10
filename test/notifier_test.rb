# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Notifier do
  let(:notifier) { Gitdocs::Notifier.new(show_notifications) }

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
            image: File.expand_path('../../lib/img/icon.png', __FILE__)
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
        Guard::Notifier.expects(:notify).with('message', title: 'title',)
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
end
