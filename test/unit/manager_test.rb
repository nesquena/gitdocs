# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe 'Gitdocs::Manager' do
  describe '.start' do
    subject { Gitdocs::Manager.start(:arg1, :arg2, :arg3) }

    before do
      Gitdocs::Manager.stubs(:new).returns(manager = stub)
      manager.expects(:start).with(:arg1, :arg2, :arg3)
    end

    it { subject }
  end

  # TODO: describe '.restart_synchronization' do

  describe '.listen_method' do
    subject { Gitdocs::Manager.listen_method }

    before { Listen::Adapter.stubs(:select).returns(listen_adapter) }

    describe 'polling' do
      let(:listen_adapter) { Listen::Adapter::Polling }
      it { subject.must_equal :polling }
    end

    describe 'notification' do
      let(:listen_adapter) { :not_polling }
      it { subject.must_equal :notification }
    end
  end

  # TODO: describe '.start'
end
