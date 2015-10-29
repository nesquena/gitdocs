# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs do
  describe 'manager controls' do
    let(:manager) { mock('Gitdocs::Manager') }

    describe '.start' do
      subject { Gitdocs.start(:override_web_port) }

      before do
        Gitdocs::Manager.expects(:new).returns(manager)
        manager.expects(:start).with(:override_web_port)
          .returns(:result)
      end

      it { subject.must_equal(:result) }
    end

    describe '.restart' do
      subject { Gitdocs.restart }

      before do
        Gitdocs.instance_variable_set(:@manager, manager)
        manager.expects(:restart).returns(:result)
      end

      it { subject.must_equal(:result) }
    end
  end

  describe '.logger' do
    subject { Gitdocs.logger }

    describe 'already exists' do
      before { Gitdocs.instance_variable_set(:@logger, :logger) }
      it { subject.must_equal(:logger) }
    end

    describe 'does not exist' do
      let(:logger) { mock('Logger') }
      before do
        Gitdocs.instance_variable_set(:@logger, nil)

        Gitdocs.stubs(:log_path).returns(:log_path)
        Gitdocs::Initializer.stubs(:foreground).returns(foreground)
        Gitdocs::Initializer.stubs(:verbose).returns(verbose)

        Logger.expects(:new).with(expected_output).returns(logger)
        logger.expects(:level=).with(expected_level)
      end

      describe 'no foreground or debug' do
        let(:foreground) { false } ; let(:verbose) { false } ; let(:expected_output) { :log_path } ; let(:expected_level)  { Logger::INFO }  ; it { subject.must_equal(logger) }
      end
      describe 'foreground' do
        let(:foreground) { false } ; let(:verbose) { true }  ; let(:expected_output) { :log_path } ; let(:expected_level)  { Logger::DEBUG } ; it { subject.must_equal(logger) }
      end
      describe 'debug' do
        let(:foreground) { true }  ; let(:verbose) { false } ; let(:expected_output) { STDOUT }    ; let(:expected_level)  { Logger::INFO }  ; it { subject.must_equal(logger) }
      end
      describe 'foreground and debug' do
        let(:foreground) { true }  ; let(:verbose) { true }  ; let(:expected_output) { STDOUT }    ; let(:expected_level)  { Logger::DEBUG } ; it { subject.must_equal(logger) }
      end
    end
  end

  describe '.log_path' do
    subject { Gitdocs.log_path }
    before do
      Gitdocs::Initializer.stubs(:root_dirname).returns(:root_dirname)
      File.expects(:expand_path).with('log', :root_dirname).returns(:result)
    end
    it { subject.must_equal(:result) }
  end

  describe 'logging wrappers' do
    let(:logger) { mock('Logger') }
    before { Gitdocs.stubs(:logger).returns(logger) }

    describe '.log_debug' do
      subject { Gitdocs.log_debug(:message) }
      before { logger.expects(:debug).with(:message) }
      specify { subject }
    end

    describe '.log_info' do
      subject { Gitdocs.log_info(:message) }
      before { logger.expects(:info).with(:message) }
      specify { subject }
    end

    describe '.log_warn' do
      subject { Gitdocs.log_warn(:message) }
      before { logger.expects(:warn).with(:message) }
      specify { subject }
    end

    describe '.log_error' do
      subject { Gitdocs.log_error(:message) }
      before { logger.expects(:error).with(:message) }
      specify { subject }
    end
  end
end
