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

  describe '.restart_synchronization' do
    subject { Gitdocs::Manager.restart_synchronization }

    before do
      Thread.expects(:main).returns(thread = mock)
      thread.expects(:raise).with(Gitdocs::Restart, 'restarting ... ')
    end

    it { subject }
  end

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

  let(:manager) { Gitdocs::Manager.new }

  describe '.start' do
    subject { manager.start(:host, :port) }

    let(:celluloid_fascade) { mock }
    before do
      Gitdocs::Initializer.stubs(:root_dirname).returns(:root_dirname)
      Gitdocs.expects(:log_info).with("Starting Gitdocs v#{Gitdocs::VERSION}...")
      Gitdocs.expects(:log_info).with("Using configuration root: 'root_dirname'")

      Gitdocs::CelluloidFascade.expects(:new)
        .with(:host, :port)
        .returns(celluloid_fascade)
#      celluloid_fascade.expects(:start)
#      manager.expects(:sleep).raises(expected_exception)
    end

    describe 'restart' do
      before do
        celluloid_fascade.expects(:start).twice
        celluloid_fascade.expects(:terminate)#.twice
        manager.stubs(:sleep).raises(Gitdocs::Restart).then.returns(:result)

        Gitdocs.expects(:log_info).with('Restarting actors...')
        Gitdocs::Notifier.expects(:disconnect)
        Gitdocs.expects(:log_info).with("Gitdocs is terminating...goodbye\n\n")
      end

      it { subject.must_equal(:result) }
    end

    describe 'exit' do
      before do
        celluloid_fascade.expects(:start)
        manager.expects(:sleep).raises(expected_exception)
      end

      describe 'Interrupt' do
        let(:expected_exception) { Interrupt }

        before do
          Gitdocs.expects(:log_info).with('Interrupt received...')
          celluloid_fascade.expects(:terminate)
          Gitdocs::Notifier.expects(:disconnect)
          Gitdocs.expects(:log_info).with("Gitdocs is terminating...goodbye\n\n")
        end

        it { subject }
      end

      describe 'SystemExit' do
        let(:expected_exception) { SystemExit }

        before do
          Gitdocs.expects(:log_info).with('Interrupt received...')
          celluloid_fascade.expects(:terminate)
          Gitdocs::Notifier.expects(:disconnect)
          Gitdocs.expects(:log_info).with("Gitdocs is terminating...goodbye\n\n")
        end

        it { subject }
      end

      describe 'unexpected Exception' do
        let(:expected_exception) { Exception.new }

        before do
          expected_exception.stubs(:backtrace).returns(%w(foo bar))
          expected_exception.stubs(:message).returns(:message)

          Gitdocs.expects(:log_error).with("#{expected_exception.inspect} - message")
          Gitdocs.expects(:log_error).with("foo\nbar")
          Gitdocs::Notifier.expects(:error).with(
            'Unexpected exit',
            'Something went wrong. Please see the log for details.'
          )
          celluloid_fascade.expects(:terminate)
          Gitdocs::Notifier.expects(:disconnect)
          Gitdocs.expects(:log_info).with("Gitdocs is terminating...goodbye\n\n")
        end

        it { proc { subject }.must_raise(Exception) }
      end
    end
  end
end
