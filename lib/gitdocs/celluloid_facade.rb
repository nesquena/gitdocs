# -*- encoding : utf-8 -*-

module Gitdocs
  class CelluloidFascade
    # @param [String] host
    # @param [Integer] port
    def initialize(host, port)
      @host = host
      @port = port
    end

    # @return [void]
    def start
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
            Host:  @host,
            Port:  @port,
            quiet: true
          }
        ]
      )

      # Start the synchronizers ################################################
      Share.all.each do |share|
        @supervisor.add(
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
    end

    # @return [void]
    def terminate
      @listener.stop        if @listener
      @supervisor.terminate if @supervisor
    end
  end
end
