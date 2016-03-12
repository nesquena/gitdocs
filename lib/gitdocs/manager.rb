# -*- encoding : utf-8 -*-

module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    # @param (see #start)
    # @return [void]
    def self.start(web_port)
      @manager.stop if @manager
      @manager = Manager.new
      @manager.start(web_port)
    end

    # @return [void]
    def self.restart_synchronization
      EM.add_timer(0.1) do
        Thread.new do
          Thread.main.raise(Restart, 'restarting ... ')
          sleep(0.1) while EM.reactor_running?

          @manager.start
        end
      end
    end

    # @return [:notification, :polling]
    def self.listen_method
      if Guard::Listener.mac? && Guard::Darwin.usable?
        :notification
      elsif Guard::Listener.linux? && Guard::Linux.usable?
        :notification
      elsif Guard::Listener.windows? && Guard::Windows.usable?
        :notification
      else
        :polling
      end
    end

    # @param [nil, #to_i] web_port
    # @return [void]
    def start(web_port)
      Gitdocs.log_info("Starting Gitdocs v#{VERSION}...")
      Gitdocs.log_info("Using configuration root: '#{Initializer.root_dirname}'")

      shares = Share.all
      Gitdocs.log_info("Monitoring shares(#{shares.length})")
      shares.each { |share| Gitdocs.log_debug("* #{share.inspect}") }

      begin
        EM.run do
          @runners = Runner.start_all(shares)
          Server.start_and_wait(web_port)
        end
      rescue Restart
        retry
      end
    rescue Exception => e # rubocop:disable RescueException
      Gitdocs.log_error(
        "#{e.class.inspect} - #{e.inspect} - #{e.message.inspect}"
      )
      Gitdocs.log_error(e.backtrace.join("\n"))
      Notifier.error(
        'Unexpected exit',
        'Something went wrong. Please see the log for details.'
      )
      raise
    ensure
      Gitdocs.log_info("Gitdocs is terminating...goodbye\n\n")
    end
  end
end
