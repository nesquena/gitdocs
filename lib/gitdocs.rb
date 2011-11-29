require 'gitdocs/version'
require 'mutex'
require 'rb-fsevent'
require 'growl_notify'

class Gitdocs
  def initialize(root)
    @root = root
    GrowlNotify.config do |config|
      config.notifications = ["Gitdocs"]
      config.application_name = "Gitdocs" #this shoes up in the growl applications list in systems settings
      config.icon = File.expand_path("../img/icon.png", __FILE__)
    end
  end

  def run
    current_revision = `git rev-parse HEAD`.strip
    mutex = Mutex.new
    Thread.new do
      mutex.synchronize do
        system("git pull") or raise
        sleep 60
      end
    end.abort_on_exception = true
    listener = FSEvent.new
    listener.watch(@root) do |directories|
      mutex.synchronize do
        system("git commit -a -m'Auto-commit from gitdocs'") or raise # TODO better commit message needed
        sleep 60
      end
    end
    listener.run
  end
end
