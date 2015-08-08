# -*- encoding : utf-8 -*-
require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Notifier do
  describe '.error' do
    describe 'with default show' do
      subject { Gitdocs::Notifier.error(:title, :message) }
      before do
        Gitdocs::Notifier.expects(:new).with(true).returns(notifier = mock)
        notifier.expects(:error).with(:title, :message)
      end
      it { subject }
    end

    describe 'with specified show' do
      subject { Gitdocs::Notifier.error(:title, :message, :show) }
      before do
        Gitdocs::Notifier.expects(:new).with(:show).returns(notifier = mock)
        notifier.expects(:error).with(:title, :message)
      end
      it { subject }
    end
  end

  describe 'instance methods' do
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
          Gitdocs.expects(:notify)
            .with('message', title: 'title', image: :success)
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
        Gitdocs.expects(:notify)
          .with('message', title: 'title', image: :pending)
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
        Gitdocs.expects(:notify)
          .with('message', title: 'title', image: :failed)
      end
      it { subject }
    end
  end
  end
end
