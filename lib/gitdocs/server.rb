# -*- encoding : utf-8 -*-

require 'thin'
require 'gitdocs/browser_app'
require 'gitdocs/settings_app'

module Gitdocs
  class Server
    def initialize(manager, port)
      @manager = manager
      @port    = port.to_i
    end

    def self.start_and_wait(manager, override_port)
      return false unless Configuration.start_web_frontend

      web_port = override_port || Configuration.web_frontend_port
      server = Server.new(manager, web_port)
      server.start
      server.wait_for_start
      true
    end

    def start
      Thin::Logging.debug = @manager.debug
      Thin::Server.start('127.0.0.1', @port) do
        use Rack::Static,
          urls: %w(/css /js /img /doc),
          root: File.expand_path('../public', __FILE__)
        use Rack::MethodOverride

        map('/settings') { run SettingsApp }
        map('/') { run BrowserApp }
      end
    end

    def wait_for_start
      wait_for_web_server = proc do
        i = 0
        begin
          TCPSocket.open('127.0.0.1', @port).close
          @manager.log('Web server running!')
        rescue Errno::ECONNREFUSED
          sleep 0.2
          i += 1
          if i <= 20
            @manager.log('Retrying web server loop...')
            retry
          else
            @manager.log('Web server failed to start')
          end
        end
      end
      EM.defer(wait_for_web_server)
    end
  end
end
