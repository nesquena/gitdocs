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
      begin
        @config = Configuration.new(config_root)
        puts "Gitdocs v#{VERSION}" if debug
        puts "Using configuration root: '#{@config.config_root}'" if debug
        puts "Watch paths: #{@config.paths.join(", ")}" if debug
        runners = []
        @threads = @config.paths.map do |path|
          t = Thread.new(runners) { |r|
            runner = Runner.new(path)
            r << runner
            runner.run
          }
          t.abort_on_exception = true
          t
        end
        sleep 1
        @pid = fork { Server.new(*runners).start }
        puts "Watch threads: #{@threads.map { |t| "Thread status: '#{t.status}', running: #{t.alive?}" }}" if debug
        puts "Joined #{@threads.size} watch threads...running" if debug
        @threads.each(&:join)
        sleep(60)
      ensure
        Process.kill("INT", @pid) rescue nil
      end
    end
    at_exit do
      Process.kill("KILL", @pid) rescue nil
    end
  end
end
