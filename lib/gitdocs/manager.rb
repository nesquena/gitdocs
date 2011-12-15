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

    def start
      self.log "Starting Gitdocs v#{VERSION}..."
      self.log "Using configuration root: '#{self.config.config_root}'"
      self.log "Shares: #{config.shares.map(&:inspect).join(", ")}"
      # Start the repo watchers
      runners = nil
      EM.run do
        self.log "Starting EM loop..."
        @runners = config.shares.map { |share| Runner.new(share) }
        @runners.each(&:run)
        # Start the web front-end
        if self.config.global.start_web_frontend
          Server.new(self, *@runners).start
          i = 0
          web_started = false
          begin
            TCPSocket.open('127.0.0.1', 8888).close
            web_started = true
          rescue Errno::ECONNREFUSED
            self.log "Retrying server loop..."
            sleep 0.2
            i += 1
            retry if i <= 20
          end
          self.log "Web server running: #{web_started}"
          system("open http://localhost:8888/") if self.config.global.load_browser_on_startup && web_started
        end
      end
    rescue Exception => e # Report all errors in log
      self.log(e.class.inspect + " - " + e.inspect + " - " + e.message.inspect, :error)
      self.log(e.backtrace.join("\n"), :error)
      raise
    ensure
      self.log("Gitdocs is terminating...goodbye\n\n")
    end

    def restart
      stop
      start
    end

    def stop
      EM.stop
    end

    protected

    # Logs and outputs to file or stdout based on debugging state
    # log("message")
    def log(msg, level=:info)
      @debug ? puts(msg) : @logger.send(level, msg)
    end
  end
end