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
      loop do
        puts "Gitdocs v#{VERSION}" if self.debug
        puts "Using configuration root: '#{self.config.config_root}'" if self.debug
        puts "Shares: #{config.shares.map(&:inspect).join(", ")}" if self.debug
        # Start the repo watchers
        runners = []
        threads = config.shares.map do |share|
          t = Thread.new(runners) { |r|
            runner = Runner.new(share)
            r << runner
            runner.run
          }
          t.abort_on_exception = true
          t
        end
        trap("USR1") { puts "stopping threads: #{threads.map(&:alive?)}"; runners.each { |r| r.listener.stop } }
        sleep 1
        unless @pid
          # Start the web front-end
          @pid = fork { Server.new(self, *runners).start }
          at_exit { Process.kill("KILL", @pid) rescue nil }
        end
        puts "Watch threads: #{threads.map { |t| "Thread status: '#{t.status}', running: #{t.alive?}" }}" if self.debug
        puts "Joined #{threads.size} watch threads...running" if self.debug
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
        threads.each(&:join)
        sleep(60) if threads.empty?
      end
    end

    def restart
      Process.kill("USR1", Process.pid)
    end
  end
end