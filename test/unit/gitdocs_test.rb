# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs do
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
    before { Celluloid.stubs(:logger).returns(logger) }

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
