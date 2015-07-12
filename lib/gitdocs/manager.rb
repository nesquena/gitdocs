# -*- encoding : utf-8 -*-

module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    # @param [nil, #to_i] override_web_port
    def start(override_web_port)
      log("Starting Gitdocs v#{VERSION}...")
      log("Using configuration root: '#{Initializer.root_dirname}'")
      shares = Share.all
      log("Shares: (#{shares.length}) #{shares.map(&:inspect).join(', ')}")

      begin
        EM.run do
          log('Starting EM loop...')

          @runners = Runner.start_all(shares)
          Server.start_and_wait(override_web_port)
        end
      rescue Restart
        retry
      end
    rescue Exception => e # rubocop:disable RescueException
      # Report all errors in log
      log("#{e.class.inspect} - #{e.inspect} - #{e.message.inspect}", :error)
      log(e.backtrace.join("\n"), :error)
      Notifier.error(
        'Unexpected exit',
        'Something went wrong. Please see the log for details.'
      )
      raise
    ensure
      log("Gitdocs is terminating...goodbye\n\n")
    end

    def restart
      Thread.new do
        Thread.main.raise Restart, 'restarting ... '
        sleep 0.1 while EM.reactor_running?
        start
      end
    end

    def stop
      EM.stop
    end

    ############################################################################

    private

    # @param [String] msg
    # @return [void]
    def log(msg)
      Gitdocs.logger.info(msg)
    end
  end
end
