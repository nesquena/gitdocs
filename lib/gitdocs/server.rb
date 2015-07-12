# -*- encoding : utf-8 -*-

require 'thin'
require 'gitdocs/browser_app'
require 'gitdocs/settings_app'

module Gitdocs
  class Server
    # @param [#to_i] port
    def initialize(port)
      @port = port.to_i
    end

    # @param [nil, #to_i] override_port
    # @return [void]
    def self.start_and_wait(override_port)
      return false unless Configuration.start_web_frontend

      web_port = override_port || Configuration.web_frontend_port
      server = Server.new(web_port)
      server.start
      server.wait_for_start
      true
    end

    def start
      Thin::Logging.debug = Initializer.debug
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
          Gitdocs.logger.info('Web server running!')
        rescue Errno::ECONNREFUSED
          sleep 0.2
          i += 1
          if i <= 20
            Gitdocs.logger.info('Retrying web server loop...')
            retry
          else
            Gitdocs.logger.info('Web server failed to start')
          end
        end
      end
      EM.defer(wait_for_web_server)
    end
  end
end
