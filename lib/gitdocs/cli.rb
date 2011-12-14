module Gitdocs
  require 'thor'

  class Cli < Thor
    include Thor::Actions

    def self.source_root; File.expand_path('../../', __FILE__); end

    desc "start", "Starts a daemonized gitdocs process"
    method_option :debug, :type => :boolean, :aliases => "-D"
    def start
      if self.stopped? && !options[:debug]
        self.runner.execute { Gitdocs.start }
        self.running? ? say("Started gitdocs", :green) : say("Failed to start gitdocs", :red)
      elsif self.stopped? && options[:debug]
        say "Starting in debug mode", :yellow
        Gitdocs.start(nil, true)
      else # already running
        say "Gitdocs is already running, please use restart", :red
      end
    end

    desc "stop", "Stops the gitdocs process"
    def stop
      if self.running?
        self.runner.execute(:kill => true)
        say "Stopped gitdocs", :red
      else # not running
        say "Gitdocs is not running", :red
      end
    end

    desc "restart", "Restarts the gitdocs process"
    def restart
      self.stop
      self.start
    end

    desc "add PATH", "Adds a path to gitdocs"
    def add(path)
      self.config.add_path(path)
      say "Added path #{path} to doc list"
      self.restart if self.running?
    end

    desc "rm PATH", "Removes a path from gitdocs"
    def rm(path)
      self.config.remove_path(path)
      say "Removed path #{path} from doc list"
      self.restart if self.running?
    end

    desc "clear", "Clears all paths from gitdocs"
    def clear
      self.config.clear
      say "Cleared paths from gitdocs"
    end

    desc "create PATH REMOTE", "Creates a new gitdoc root based on an existing remote"
    def create(path, remote)
      FileUtils.mkdir_p(File.dirname(path))
      system("git clone -q #{remote} #{ShellTools.escape(path)}") or raise "Unable to clone into #{path}"
      self.add(path)
      say "Created #{path} path for gitdoc"
    end

    desc "status", "Retrieve gitdocs status"
    def status
      say "GitDoc v#{VERSION}"
      say "Running: #{self.running?}"
      say "Watching paths:"
      say self.config.shares.map { |s| "  - #{s.path}" }.join("\n")
    end

    desc "config", "Configuration options for gitdocs"
    def config
      # TODO make this work
    end

    desc "help", "Prints out the help"
    def help(task = nil, subcommand = false)
      say "\nGitdocs: Collaborate with ease.\n\n"
      task ? self.class.task_help(shell, task) : self.class.help(shell, subcommand)
    end

    # Helpers for thor
    no_tasks do
      def runner(options={})
        Dante::Runner.new('gitdocs', options.merge(:debug => false, :daemonize => true, :pid_path => self.pid_path))
      end

      def config
        @config ||= Configuration.new
      end

      def running?
        self.runner.daemon_running?
      end

      def stopped?
        self.runner.daemon_stopped?
      end

      def pid_path
        "/tmp/gitdocs.pid"
      end
    end

  end
end
