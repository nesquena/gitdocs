ENV['TEST'] = 'true'
require 'rubygems'
require 'minitest/autorun'
$LOAD_PATH.unshift File.expand_path('../../lib')
require 'gitdocs'
require 'fakeweb'
require 'mocha/setup'

FakeWeb.allow_net_connect = false

## Kernel Extensions
require 'stringio'

class MiniTest::Spec
  def with_clones(count = 3)
    FileUtils.rm_rf('/tmp/gitdocs')
    master_path = '/tmp/gitdocs/master'
    FileUtils.mkdir_p('/tmp/gitdocs/master')
    ShellTools.capture { `git init /tmp/gitdocs/master --bare` }
    sub_paths = count.times.map do |c|
      ShellTools.capture { `cd /tmp/gitdocs && git clone file://#{master_path} #{c}` }
      ShellTools.capture { `cd /tmp/gitdocs/#{c} && git config --local user.email "afish@example.com" && git config --local user.name "Art T. Fish"` }
      conf_path = "/tmp/gitdocs/config/#{c}"
      FileUtils.mkdir_p(conf_path)
      ["/tmp/gitdocs/#{c}", conf_path]
    end
    pids = sub_paths.map do |(path, conf_path)|
      fork do
      unless ENV['DEBUG']
        STDOUT.reopen(File.open('/dev/null', 'w'))
        STDERR.reopen(File.open('/dev/null', 'w'))
      end
      begin
        puts 'RUNNING!'
        Gitdocs.start(config_path: conf_path) do |conf|
          conf.global.update_attributes(load_browser_on_startup: false, start_web_frontend: false)
          conf.add_path(path, polling_interval: 0.1, notification: false)
        end
      rescue
        puts 'RATHER BAD ~~~~~'
        puts $ERROR_INFO.message
        puts $ERROR_INFO.backtrace.join("\n  ")
        end
      end
    end
    begin
      sleep 1
      yield sub_paths.map { |sp| sp.first }
    ensure
      pids.each { |pid| Process.kill('INT', pid) rescue nil }
    end
  ensure
    FileUtils.rm_rf('/tmp/gitdocs') unless ENV['DEBUG']
  end
end
