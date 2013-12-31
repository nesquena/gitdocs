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

    RepoDescriptor = Struct.new(:name, :index)

    def search(term)
      results = {}
      @runners.each_with_index do |runner, index|
        descriptor = RepoDescriptor.new(runner.root, index)
        repo_results = runner.search(term)
        results[descriptor] = repo_results unless repo_results.empty?
      end
      results
    end

    def start(web_port = nil)
      log("Starting Gitdocs v#{VERSION}...")
      log("Using configuration root: '#{config.config_root}'")
      log("Shares: (#{config.shares.length}) #{config.shares.map(&:inspect).join(', ')}")

      restarting = false
      begin
        EM.run do
          log('Starting EM loop...')

          @runners = Runner.start_all(config.shares)

          # Start the web front-end
          if config.global.start_web_frontend
            web_port ||= config.global.web_frontend_port
            web_server = Server.new(self, web_port, *@runners)
            web_server.start
            web_server.wait_for_start_and_open(restarting)
          end
        end
      rescue Restart
        restarting = true
        retry
      end
    rescue Exception => e # Report all errors in log
      self.log(e.class.inspect + " - " + e.inspect + " - " + e.message.inspect, :error)
      self.log(e.backtrace.join("\n"), :error)

      #HACK duplicating the error notification code from the Runner
      begin
        title = 'Unexpected exit'
        msg   = 'Something went wrong. Please see the log for details.'

        if @show_notifications
          Guard::Notifier.notify(
            msg,
            :title => 'Unexpected exit. Please see the log for details',
            :image => :failure
          )
        else
          Kernel.warn("#{title}: #{msg}")
        end
      rescue
        # do nothing, This contain any exceptions which might be thrown by
        # the notification.
      end

      raise
    ensure
      self.log("Gitdocs is terminating...goodbye\n\n")
    end

    def restart
      Thread.new do
        Thread.main.raise Restart, "restarting ... "
        sleep 0.1 while EM.reactor_running?
        start
      end
    end

    def stop
      EM.stop
    end

    # Logs and outputs to file or stdout based on debugging state
    # log("message")
    def log(msg, level=:info)
      @debug ? puts(msg) : @logger.send(level, msg)
    end
  end
end
