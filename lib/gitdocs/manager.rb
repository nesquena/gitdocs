# -*- encoding : utf-8 -*-

module Gitdocs
  Restart = Class.new(RuntimeError)

  class Manager
    # @param (see #start)
    # @return (see #start)
    def self.start(web_port)
      Manager.new.start(web_port)
    end

    # @return [void]
    def self.restart_synchronization
      Thread.main.raise(Restart, 'restarting ... ')
    end

    # @return [:notification, :polling]
    def self.listen_method
      return :polling if Listen::Adapter.select == Listen::Adapter::Polling
      :notification
    end

    # @param [Integer] web_port
    # @return [void]
    def start(web_port)
      Gitdocs.log_info("Starting Gitdocs v#{VERSION}...")
      Gitdocs.log_info(
        "Using configuration root: '#{Initializer.root_dirname}'"
      )

      Celluloid.boot unless Celluloid.running?
      @supervisor = Celluloid::SupervisionGroup.run!

      # Start the web server ###################################################
      app =
        Rack::Builder.new do
          use Rack::Static,
              urls: %w(/css /js /img /doc),
              root: File.expand_path('../public', __FILE__)
          use Rack::MethodOverride
          map('/settings') { run SettingsApp }
          map('/')         { run BrowserApp }
        end
      @supervisor.add(
        Reel::Rack::Server,
        as: :reel_rack_server,
        args: [
          app,
          {
            Host:  '127.0.0.1',
            Port:  web_port,
            quiet: true
          }
        ]
      )

      # Start the synchronizers ################################################
      @synchronization_supervisor = Celluloid::SupervisionGroup.run!
      Share.all.each do |share|
        @synchronization_supervisor.add(
          Synchronizer, as: share.id.to_s, args: [share]
        )
      end

      # Start the repository listeners #########################################
      @listener =
        Listen.to(
          *Share.paths,
          ignore: /#{File::SEPARATOR}\.git#{File::SEPARATOR}/
        ) do |modified, added, removed|
          all_changes = modified + added + removed
          changed_repository_paths =
            Share.paths.select do |directory|
              all_changes.any? { |x| x.start_with?(directory) }
            end

          changed_repository_paths.each do |directory|
            actor_id = Share.find_by_path(directory).id.to_s
            Celluloid::Actor[actor_id].async.synchronize
          end
        end
      @listener.start

      # ... and wait ###########################################################
      sleep

    rescue Interrupt
      Gitdocs.log_info('Interrupt received...')
    rescue Exception => e # rubocop:disable RescueException
      Gitdocs.log_error(
        "#{e.class.inspect} - #{e.inspect} - #{e.message.inspect}"
      )
      Gitdocs.log_error(e.backtrace.join("\n"))
      Notifier.error(
        'Unexpected exit',
        'Something went wrong. Please see the log for details.'
      )
      raise
    ensure
      Gitdocs.log_info('stopping listeners...')
      @listener.stop if @listener

      Gitdocs.log_info('stopping synchronizers...')
      @synchronization_supervisor.terminate if @synchronization_supervisor

      Gitdocs.log_info('terminate supervisor...')
      @supervisor.terminate if @supervisor

      Gitdocs.log_info('disconnect notifier...')
      Notifier.disconnect

      Gitdocs.log_info("Gitdocs is terminating...goodbye\n\n")
    end
  end
end
