ENV["TEST"] = 'true'
require 'rubygems'
require 'minitest/autorun'
$:.unshift File.expand_path("../../lib")
require 'gitdocs'
require 'fakeweb'
require 'mocha'

FakeWeb.allow_net_connect = false

## Kernel Extensions
require 'stringio'

module Kernel
  # Redirect standard out, standard error and the buffered logger for sprinkle to StringIO
  # capture_stdout { any_commands; you_want } => "all output from the commands"
  def capture_out
    yield and return if ENV['DEBUG']
    begin
      old_out, old_err = STDOUT.dup, STDERR.dup
      stdout_read, stdout_write = IO.pipe
      stderr_read, stderr_write = IO.pipe
      $stdout.reopen(stdout_write)
      $stderr.reopen(stderr_write)
      yield
      stdout_write.close
      stderr_write.close
      out = stdout_read.rewind && stdout_read.read rescue nil
      err = stderr_read.rewind && stderr_read.read rescue nil
      [out, err]
    ensure
      $stdout.reopen(old_out)
      $stderr.reopen(old_err)
    end
  end
end

class MiniTest::Spec
  def with_clones(count = 3)
    FileUtils.rm_rf("/tmp/gitdocs")
    master_path = "/tmp/gitdocs/master"
    FileUtils.mkdir_p("/tmp/gitdocs/master")
    capture_out { `git init /tmp/gitdocs/master --bare` }
    sub_paths = count.times.map do |c|
      capture_out { `cd /tmp/gitdocs && git clone file://#{master_path} #{c}` }
      "/tmp/gitdocs/#{c}"
    end
    pids = sub_paths.map { |path| fork do
      unless ENV['DEBUG']
        STDOUT.reopen(File.open("/dev/null", 'w'))
        STDERR.reopen(File.open("/dev/null", 'w'))
      end
      begin
        Gitdocs::Runner.new(Gitdocs::Configuration::Share.new(:path => path, :polling_interval => 15, :growl => true)).run
      rescue
        puts "RATHER BAD ~~~~~"
        puts $!.message
        puts $!.backtrace.join("\n  ")
      end
    end }
    begin
      sleep 0.1
      yield sub_paths
    ensure
      pids.each { |pid| Process.kill("INT", pid) rescue nil }
    end
  ensure
    FileUtils.rm_rf("/tmp/gitdocs") unless ENV['DEBUG']
  end
end
