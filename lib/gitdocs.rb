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
  def self.run(config_root = nil)
    loop do
      @config = Configuration.new(config_root)
      @threads = @config.paths.map do |path|
        t = Thread.new { Runner.new(path).run }
        t.abort_on_exception = true
        t
      end
      @threads.each(&:join)
      sleep(60)
    end
  end
end
