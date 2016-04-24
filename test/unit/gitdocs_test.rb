# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'Gitdocs' do
  describe '.log_path' do
    subject { Gitdocs.log_path }
    before do
      Gitdocs::Initializer.stubs(:root_dirname).returns(:root_dirname)
      File.stubs(:expand_path).with('log', :root_dirname).returns(:result)
    end
    it { subject.must_equal(:result) }
  end

  describe 'log wrappers' do
    let(:logger) { stubs('Logger') }

    before do
      Gitdocs::Initializer.stubs(:foreground).returns(foreground)
      Gitdocs::Initializer.stubs(:verbose).returns(verbose)
      Gitdocs.stubs(:log_path).returns(:log_path)

      Gitdocs.instance_variable_set(:@logger, nil)
      Logger.stubs(:new).with(expected_path).returns(logger)
      logger.expects(:level=).with(expected_level)
    end

    describe 'background and non-verbose' do
      let(:foreground)     { false }
      let(:verbose)        { false }
      let(:expected_path)  { :log_path }
      let(:expected_level) { Logger::INFO }

      describe '.log_debug' do
        subject { Gitdocs.log_debug(:message) }
        before { logger.expects(:debug).with(:message) }
        it { subject }
      end

      describe '.log_info' do
        subject { Gitdocs.log_info(:message) }
        before { logger.expects(:info).with(:message) }
        it { subject }
      end

      describe '.log_warn' do
        subject { Gitdocs.log_warn(:message) }
        before { logger.expects(:warn).with(:message) }
        it { subject }
      end

      describe '.log_error' do
        subject { Gitdocs.log_error(:message) }
        before { logger.expects(:error).with(:message) }
        it { subject }
      end
    end

    describe 'foreground and verborse' do
      let(:foreground)     { true }
      let(:verbose)        { true }
      let(:expected_path)  { STDOUT }
      let(:expected_level) { Logger::DEBUG }

      describe '.log_debug' do
        subject { Gitdocs.log_debug(:message) }
        before { logger.expects(:debug).with(:message) }
        it { subject }
      end

      describe '.log_info' do
        subject { Gitdocs.log_info(:message) }
        before { logger.expects(:info).with(:message) }
        it { subject }
      end

      describe '.log_warn' do
        subject { Gitdocs.log_warn(:message) }
        before { logger.expects(:warn).with(:message) }
        it { subject }
      end

      describe '.log_error' do
        subject { Gitdocs.log_error(:message) }
        before { logger.expects(:error).with(:message) }
        it { subject }
      end
    end
  end
end
