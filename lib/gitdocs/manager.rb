# -*- encoding : utf-8 -*-

module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    # @param (see #start)
    # @return (see #start)
    def self.start(*args)
      Manager.new.start(*args)
    end

    # @return [void]
    def self.restart_synchronization
      Thread.main.raise(Restart, 'restarting ... ')
    end

    # @return [:notification, :polling]
    def self.listen_method
      return :polling if Listen::Adapter.select == Listen::Adapter::Polling
      :notification
    end

    # @param [String] host
    # @param [Integer] port
    # @return [void]
    def start(host, port)
      Gitdocs.log_info("Starting Gitdocs v#{VERSION}...")
      Gitdocs.log_info(
        "Using configuration root: '#{Initializer.root_dirname}'"
      )

      @celluloid = Gitdocs::CelluloidFascade.new(host, port)

      begin
        @celluloid.start
        # ... and wait ###########################################################
        sleep
      rescue Restart
        Gitdocs.log_info('Restarting actors...')
        @celluloid.terminate
        retry
      rescue Interrupt, SystemExit
        Gitdocs.log_info('Interrupt received...')
        @celluloid.terminate
      rescue Exception => e # rubocop:disable RescueException
        Gitdocs.log_error("#{e.inspect} - #{e.message}")
        Gitdocs.log_error(e.backtrace.join("\n"))
        Notifier.error(
          'Unexpected exit',
          'Something went wrong. Please see the log for details.'
        )
        @celluloid.terminate

        raise
      ensure
        Notifier.disconnect
        Gitdocs.log_info("Gitdocs is terminating...goodbye\n\n")
      end
    end
  end
end
