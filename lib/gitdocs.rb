require 'gitdocs/version'
require 'gitdocs/configuration'
require 'gitdocs/runner'
require 'gitdocs/server'
require 'gitdocs/cli'
require 'thread'
require 'rb-fsevent'
require 'growl'
require 'yajl'
require 'dante'


module Gitdocs

  DEBUG = ENV['DEBUG']

  def self.run(config_root = nil, debug = DEBUG)
    loop do
      config = Configuration.new(config_root)
      puts "Gitdocs v#{VERSION}" if debug
      puts "Using configuration root: '#{config.config_root}'" if debug
      puts "Watch paths: #{config.paths.join(", ")}" if debug
      runners = []
      threads = config.paths.map do |path|
        t = Thread.new(runners) { |r|
          runner = Runner.new(path)
          r << runner
          runner.run
        }
        t.abort_on_exception = true
        t
      end
      sleep 1
      unless pid
        pid = fork { Server.new(*runners).start }
        at_exit { Process.kill("KILL", pid) rescue nil }
      end
      puts "Watch threads: #{threads.map { |t| "Thread status: '#{t.status}', running: #{t.alive?}" }}" if debug
      puts "Joined #{threads.size} watch threads...running" if debug
      threads.each(&:join)
      sleep(60)
    end
  end
end
