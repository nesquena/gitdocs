# -*- encoding : utf-8 -*-

module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    attr_reader :config, :debug

    def initialize(config_root, debug)
      @config = Configuration.new(config_root)
      @logger = Logger.new(File.expand_path('log', @config.config_root))
      @debug  = debug
      yield @config if block_given?
    end

    def start(web_port = nil)
      log("Starting Gitdocs v#{VERSION}...")
      log("Using configuration root: '#{config.config_root}'")
      log("Shares: (#{shares.length}) #{shares.map(&:inspect).join(', ')}")

      restarting = false
      begin
        EM.run do
          log('Starting EM loop...')

          @runners = Runner.start_all(shares)

          # Start the web front-end
          if config.start_web_frontend
            web_port ||= config.web_frontend_port
            repositories = shares.map { |x| Repository.new(x) }
            web_server = Server.new(self, web_port, repositories)
            web_server.start
            web_server.wait_for_start_and_open(restarting)
          end
        end
      rescue Restart
        restarting = true
        retry
      end
    rescue Exception => e # Report all errors in log
      log(e.class.inspect + ' - ' + e.inspect + ' - ' + e.message.inspect, :error)
      log(e.backtrace.join("\n"), :error)
      Gitdocs::Notifier.error(
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

    # Logs and outputs to file or stdout based on debugging state
    # log("message")
    def log(msg, level = :info)
      @debug ? puts(msg) : @logger.send(level, msg)
    end

    def web_frontend_port
      config.web_frontend_port
    end

    def shares
      config.shares
    end

    # @see Gitdocs::Configuration#update_all
    def update_all(new_config)
      config.update_all(new_config)
      EM.add_timer(0.1) { manager.restart }
    end

    # @see Gitdocs::Configuration#remove_by_id
    def remove_by_id(id)
      config.remove_by_id(id)
    end
  end
end
