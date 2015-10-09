# -*- encoding : utf-8 -*-

require 'thin'
require 'gitdocs/browser_app'
require 'gitdocs/settings_app'

module Gitdocs
  class Server
    # @param [#to_i] port
    # @param [String] host
    def initialize(port, host = '127.0.0.1')
      @host = host
      @port = port.to_i
    end

    # @param [nil, #to_i] override_port
    # @return [void]
    def self.start_and_wait(override_port, override_host)
      return false unless Configuration.start_web_frontend

      web_port = override_port || Configuration.web_frontend_port
      web_host = override_host || Configuration.web_frontend_host
      server = Server.new(web_port, web_host)
      server.start
      server.wait_for_start
      true
    end

    def start
      Thin::Logging.debug = Initializer.debug
      Thin::Server.start(@host, @port) do
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
          TCPSocket.open(@host, @port).close
          Gitdocs.logger.info("Web server running (address #{@host} & port #{@port})")
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
