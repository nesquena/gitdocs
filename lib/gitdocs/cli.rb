module Gitdocs
  require 'thor'

  class Cli < Thor
    include Thor::Actions

    def self.source_root; File.expand_path('../../', __FILE__); end

    desc 'start', 'Starts a daemonized gitdocs process'
    method_option :debug, type: :boolean, aliases: '-D'
    method_option :port, type: :string, aliases: '-p'
    method_option :pid, type: :string, aliases: '-P'
    def start
      unless stopped?
        say 'Gitdocs is already running, please use restart', :red
        return
      end

      if options[:debug]
        say 'Starting in debug mode', :yellow
        Gitdocs.start(debug: true, port: options[:port])
      else
        runner.execute { Gitdocs.start(port: options[:port]) }
        if running?
          say 'Started gitdocs', :green
        else
          say 'Failed to start gitdocs', :red
        end
      end
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'stop', 'Stops the gitdocs process'
    def stop
      unless running?
        say 'Gitdocs is not running', :red
        return
      end

      runner.execute(kill: true)
      say 'Stopped gitdocs', :red
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'restart', 'Restarts the gitdocs process'
    def restart
      stop
      start
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'add PATH', 'Adds a path to gitdocs'
    def add(path)
      config.add_path(path)
      say "Added path #{path} to doc list"
      restart if running?
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'rm PATH', 'Removes a path from gitdocs'
    def rm(path)
      config.remove_path(path)
      say "Removed path #{path} from doc list"
      restart if running?
    end

    desc 'clear', 'Clears all paths from gitdocs'
    def clear
      config.clear
      say 'Cleared paths from gitdocs'
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'create PATH REMOTE', 'Creates a new gitdoc root based on an existing remote'
    def create(path, remote)
      Gitdocs::Repository.clone(path, remote)
      add(path)
      say "Created #{path} path for gitdoc"
    end

    method_option :pid, type: :string, aliases: '-P'
    desc 'status', 'Retrieve gitdocs status'
    def status
      say "GitDoc v#{VERSION}"
      say "Running: #{running?}"
      say "File System Watch Method: #{file_system_watch_method}"
      say 'Watched repositories:'
      tp.set :max_width, 100
      status_display = lambda do |share|
        repository = Gitdocs::Repository.new(share)

        status = ''
        status += '*' if repository.dirty?

        status = '✓' if status.empty?
        status
      end
      tp config.shares,
        { sync: { display_method: :sync_type } },
        { s: status_display },
        :path
      say "\n(Legend: ✓ everything synced, * change to commit)"
    end

    desc 'open', 'Open the Web UI'
    method_option :port, type: :string, aliases: '-p'
    def open
      unless running?
        say 'Gitdocs is not running, cannot open the UI', :red
        return
      end

      web_port = options[:port]
      web_port ||= config.global.web_frontend_port
      Launchy.open("http://localhost:#{web_port}/")
    end

    # TODO: make this work
    #desc 'config', 'Configuration options for gitdocs'
    #def config
    #end

    desc 'help', 'Prints out the help'
    def help(task = nil, subcommand = false)
      say "\nGitdocs: Collaborate with ease.\n\n"
      task ? self.class.task_help(shell, task) : self.class.help(shell, subcommand)
    end

    # Helpers for thor
    no_tasks do
      def runner
        Dante::Runner.new(
          'gitdocs',
          debug:     false,
          daemonize: true,
          pid_path: pid_path
        )
      end

      def config
        @config ||= Configuration.new
      end

      def running?
        runner.daemon_running?
      end

      def stopped?
        runner.daemon_stopped?
      end

      def pid_path
        options[:pid] || '/tmp/gitdocs.pid'
      end

      # @return [Symbol] to indicate how the file system is being watched
      def file_system_watch_method
        if Guard::Listener.mac? && Guard::Darwin.usable?
          :notification
        elsif Guard::Listener.linux? && Guard::Linux.usable?
          :notification
        elsif Guard::Listener.windows? && Guard::Windows.usable?
          :notification
        else
          :polling
        end
      end
    end
  end
end
