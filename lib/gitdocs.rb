# -*- encoding : utf-8 -*-

require 'thread'
require 'dante'
require 'socket'
require 'shell_tools'
require 'grit'
require 'rugged'
require 'table_print'

require 'celluloid'
require 'listen'
require 'reel/rack'
require 'sinatra/base'
require 'notiffany'

require 'gitdocs/version'
require 'gitdocs/initializer'
require 'gitdocs/share'
require 'gitdocs/configuration'
require 'gitdocs/cli'
require 'gitdocs/syncronizer'
require 'gitdocs/cells/notifier'
require 'gitdocs/notifier'
require 'gitdocs/syncronization_notifier'
require 'gitdocs/settings_app'
require 'gitdocs/browser_app'
require 'gitdocs/repository'
require 'gitdocs/repository/path'
require 'gitdocs/repository/invalid_error'
require 'gitdocs/repository/committer'
require 'gitdocs/repository/syncronizer'
require 'gitdocs/search'

module Gitdocs
  class Timer
    include Celluloid
  end

  # @param [nil, Integer] override_web_port
  # @return [void]
  def self.start(override_web_port)
    return if @running

    Celluloid.logger =
      if Initializer::debug
        Logger.new(STDOUT)
      else
        Logger.new(File.expand_path('log', Initializer.root_dirname))
      end

    Celluloid.boot unless Celluloid.running?
    @supervisor = Celluloid::SupervisionGroup.run!
    @supervisor.add(Gitdocs::Syncronizer, as: :syncronizer)
    @supervisor.add(Gitdocs::Cells::Notifier, as: :notifier)

    @supervisor.add(Timer, as: :timer)
    Share.which_need_fetch.each do |share|
      Celluloid::Actor[:timer].every(share.polling_interval) do
        Celluloid::Actor[:syncronizer].commit_and_syncronize(share)
      end
    end

    app =
      Rack::Builder.new do
        use Rack::Static,
          urls: %w(/css /js /img /doc),
          root: File.expand_path('../gitdocs/public', __FILE__)
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
            Port:  override_web_port || Configuration.web_frontend_port,
            quiet: false
          }
        ]
      )

    start_listeners
    @running = true
  end

  # @param (see .start)
  def self.start_and_sleep(*args)
    start(*args)
    sleep
  rescue Interrupt
    logger.info('Interrupt received... Gitdocs stopping')

    @listener.stop        if @listener
    @supervisor.terminate if @supervisor

    logger.info('Done')
  end

  # @return [Logger]
  def self.logger
    Celluloid.logger
  end

  # @param (see Gitdocs::Celluloid::Notifier#notify)
  # @return (see Gitdocs::Celluloid::Notifier#notify)
  def self.notify(*args)
    Celluloid::Actor[:notifier].notify(*args)
  end

  # @return [:polling, :notification]
  def self.file_system_watch_method
    return :polling if Listen::Adapter.select == Listen::Adapter::Polling
    :notification
  end

  private_class_method

  # @return [void]
  def self.start_listeners
    @listener.stop if @listener

    @listener =
      Listen.to(
        *Share.paths_to_sync,
        ignore: %r(#{File::SEPARATOR}\.git#{File::SEPARATOR})
      ) do |modified, added, removed|
        all_changes = modified + added + removed
        all_changes.uniq!
        Share.which_include(all_changes).map do |share|
          Celluloid::Actor[:syncronizer].commit_and_sync(share)
        end
      end
    @listener.start
  end
end
