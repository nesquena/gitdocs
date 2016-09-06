# -*- encoding : utf-8 -*-

# rubocop:disable LineLength, ClassLength

module Gitdocs
  require 'thor'

  class Cli < Thor
    include Thor::Actions

    def self.source_root
      File.expand_path('../../', __FILE__)
    end

    desc 'start', 'Starts a daemonized gitdocs process'
    method_option :foreground, type: :boolean, aliases: '-fg'
    method_option :verbose,    type: :boolean, aliases: '-v'
    method_option :port,       type: :string,  aliases: '-p'
    method_option :pid,        type: :string,  aliases: '-P'
    def start
      unless stopped?
        say 'Gitdocs is already running, please use restart', :red
        return
      end

      Gitdocs::Initializer.verbose = options[:verbose]

      if options[:foreground]
        say 'Run in the foreground', :yellow
        Gitdocs::Initializer.foreground = true
        Manager.start(web_port)
      else
        # Clear the arguments so that they will not be processed by the
        # Dante execution.
        ARGV.clear
        runner.execute { Manager.start(web_port) }

        if running?
          say 'Started gitdocs', :green
        else
          say 'Failed to start gitdocs', :red
        end
      end
    end

    desc 'stop', 'Stops the gitdocs process'
    method_option :pid, type: :string, aliases: '-P'
    def stop
      unless running?
        say 'Gitdocs is not running', :red
        return
      end

      runner.execute(kill: true)
      say 'Stopped gitdocs', :red
    end

    desc 'restart', 'Restarts the gitdocs process'
    method_option :pid, type: :string, aliases: '-P'
    def restart
      stop
      start
    end

    desc 'add PATH', 'Adds a path to gitdocs'
    method_option :pid,          type: :string,  aliases: '-P'
    method_option :interval,     type: :numeric, aliases: '-i', default: 15
    method_option :notification, type: :boolean, aliases: '-n', default: true
    method_option :sync,         type: :boolean, aliases: '-s', default: 'full'
    def add(path)
      Share.create_by_path!(
        normalize_path(path),
        polling_interval: options[:interval],
        notification:     options[:notification],
        sync_type:        options[:sync]
      )
      say "Added path #{path} to doc list"
      restart if running?
    end

    desc 'create PATH REMOTE', 'Creates a new gitdoc root based on an existing remote'
    method_option :pid,          type: :string,  aliases: '-P'
    method_option :interval,     type: :numeric, aliases: '-i', default: 15
    method_option :notification, type: :boolean, aliases: '-n', default: true
    method_option :sync,         type: :boolean, aliases: '-s', default: 'full'
    def create(path, remote)
      Repository.clone(path, remote)
      Share.create_by_path!(
        normalize_path(path),
        polling_interval: options[:interval],
        notification:     options[:notification],
        sync_type:        options[:sync]
      )
      say "Cloned and added path #{path} to doc list"
      restart if running?
    end

    desc 'rm PATH', 'Removes a path from gitdocs'
    method_option :pid, type: :string, aliases: '-P'
    def rm(path)
      Share.remove_by_path(path)
      say "Removed path #{path} from doc list"
      restart if running?
    end

    desc 'clear', 'Clears all paths from gitdocs'
    method_option :pid, type: :string, aliases: '-P'
    def clear
      Share.destroy_all
      say 'Cleared paths from gitdocs'
      restart if running?
    end

    desc 'status', 'Retrieve gitdocs status'
    method_option :pid, type: :string, aliases: '-P'
    def status
      say "GitDoc v#{VERSION}"
      say "Running: #{running?}"
      say "File System Watch Method: #{Gitdocs::Manager.listen_method}"
      say 'Watched repositories:'
      tp.set(:max_width, 100)
      status_display = lambda do |share|
        repository = Repository.new(share)

        status = ''
        status += '*' if repository.dirty?
        status += '!' if repository.need_sync?

        status = 'ok' if status.empty?
        status
      end
      tp(
        Share.all,
        { sync: { display_method: :sync_type } },
        { s: status_display },
        :path
      )
      say "\n(Legend: ok everything synced, * change to commit, ! needs sync)"
    end

    desc 'open', 'Open the Web UI'
    method_option :port, type: :string, aliases: '-p'
    def open
      unless running?
        say 'Gitdocs is not running, cannot open the UI', :red
        return
      end

      Launchy.open("http://localhost:#{web_port}/")
    end

    # TODO: make this work
    # desc 'config', 'Configuration options for gitdocs'
    # def config
    # end

    desc 'help', 'Prints out the help'
    def help(task = nil, subcommand = false)
      say "\nGitdocs: Collaborate with ease.\n\n"
      task ? self.class.task_help(shell, task) : self.class.help(shell, subcommand)
    end

    # Helpers for thor
    no_tasks do
      # @return [Dante::Runner]
      def runner
        Dante::Runner.new(
          'gitdocs',
          debug:     false,
          daemonize: true,
          pid_path:  pid_path,
          log_path:  Gitdocs.log_path
        )
      end

      # @return [Boolean]
      def running?
        runner.daemon_running?
      end

      # @return [Boolean]
      def stopped?
        runner.daemon_stopped?
      end

      # @return [String]
      def pid_path
        options[:pid] || '/tmp/gitdocs.pid'
      end

      # @return [Integer]
      def web_port
        result = options[:port]
        result ||= Configuration.web_frontend_port
        result.to_i
      end

      # @param [String] path
      # @return [String]
      def normalize_path(path)
        File.expand_path(path, Dir.pwd)
      end
    end
  end
end
