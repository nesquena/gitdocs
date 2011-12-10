module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    attr_reader :config, :debug

    def initialize(config_root, debug)
      @config = Configuration.new(config_root)
      @debug  = debug
      yield @config if block_given?
    end

    def run
      run = true
      trap('USR1') { run = true; EM.stop }
      while run
        run = false
        puts "Gitdocs v#{VERSION}" if self.debug
        puts "Using configuration root: '#{self.config.config_root}'" if self.debug
        puts "Shares: #{config.shares.map(&:inspect).join(", ")}" if self.debug
        # Start the repo watchers
        runners = nil
        EM.run do
          runners = config.shares.map { |share| Runner.new(share) }
          runners.each(&:run)
          # Start the web front-end
          if self.config.global.start_web_frontend
            Server.new(self, *runners).start
            i = 0
            web_started = false
            begin
              TCPSocket.open('127.0.0.1', 8888).close
              web_started = true
            rescue Errno::ECONNREFUSED
              sleep 0.2
              i += 1
              retry if i <= 20
            end
            system("open http://localhost:8888/") if self.config.global.load_browser_on_startup && web_started
          end
        end
        sleep(10) if runners && runners.empty?
      end
    end

    def restart
      Process.kill("USR1", Process.pid)
    end
  end
end