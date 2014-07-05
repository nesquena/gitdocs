# -*- encoding : utf-8 -*-

# Disable style checks that are invalid for Renee
# rubocop:disable Blocks, MultilineBlockChain

require 'thin'
require 'renee'
require 'coderay'
require 'uri'
require 'haml'
require 'mimetype_fu'
require 'launchy'

module Gitdocs
  class Server
    def initialize(manager, port = 8888, repositories)
      @manager      = manager
      @port         = port.to_i
      @repositories = repositories
      @search       = Gitdocs::Search.new(repositories)
    end

    def self.start_and_wait(manager, override_port, repositories)
      return false unless manager.start_web_frontend

      web_port = override_port || manager.web_frontend_port
      server = Server.new(manager, web_port, repositories)
      server.start
      server.wait_for_start
      true
    end

    def start
      repositories = @repositories
      manager      = @manager
      Thin::Logging.debug = @manager.debug
      Thin::Server.start('127.0.0.1', @port) do
        use Rack::Static, urls: %w(/css /js /img /doc), root: File.expand_path('../public', __FILE__)
        use Rack::MethodOverride
        run Renee {
          if request.path_info == '/'
            if manager.shares.size == 1
              redirect! '/0'
            else
              render!(
                'home',
                layout: 'app',
                locals: { shares: manager.shares, nav_state: 'home' }
              )
            end
          else
            path 'settings' do
              get.render!(
                'settings',
                layout: 'app',
                locals: { conf: manager, nav_state: 'settings' }
              )
              post do
                manager.update_all(request.POST)
                redirect! '/settings'
              end
            end

            path('search').get do
              render!(
                'search',
                layout: 'app',
                locals: { results: @search.search(request.GET['q']), nav_state: nil }
              )
            end

            path('shares') do
              post do
                Configuration::Share.create
                redirect!('/settings')
              end

              var(:int) do |id|
                delete do
                  halt(404) unless manager.remove_by_id(id)
                  redirect!('/settings')
                end
              end
            end

            var :int do |idx|
              halt(404) unless repositories[idx]
              path = Gitdocs::Repository::Path.new(
                repositories[idx], URI.unescape(request.path_info)
              )

              mode   = request.params['mode']
              default_locals = {
                idx:       idx,
                root:      repository.root,
                nav_state: nil
              }

              if mode == 'meta' # Meta
                halt 200, { 'Content-Type' => 'application/json' }, [path.meta.to_json]
              elsif mode == 'save' # Saving
                path.write(request.params['data'], request.params['message'])
                redirect!("/#{idx}/#{path.relative_path}")
              elsif mode == 'upload'  # Uploading
                file = request.params['file']
                halt 404 unless file
                tempfile = file[:tempfile]
                filename = file[:filename]
                FileUtils.mv(tempfile.path, path.absolute_path)
                redirect!("/#{idx}/#{path.relative_path}/#{filename}")
              elsif !path.exist? && !request.params['dir'] # edit for non-existent file
                path.touch
                redirect!("/#{idx}/#{path.relative_path}?mode=edit")
              elsif !path.exist? && request.params['dir'] # create directory
                path.mkdir
                redirect!("/#{idx}/#{path.relative_path}")
              elsif path.directory? # list directory
                rendered_readme =
                  if path.readme_path
                    <<-EOS.gusb(/^\s+/, '')
                      <h3>#{File.basename(path.readme_path)}</h3>
                      <div class="tilt">#{render(path.readme_path)}</div>
                    EOS
                  else
                    nil
                  end
                render!(
                  'dir',
                  layout: 'app',
                  locals: default_locals.merge(
                    contents:        path.file_listing,
                    rendered_readme: rendered_readme
                  )
                )
              elsif mode == 'revisions' # list revisions
                render!(
                  'revisions',
                  layout: 'app',
                  locals: default_locals.merge(revisions: path.revisions)
                )
              elsif mode == 'revert' # revert file
                path.revert(request.params['revision'])
                redirect!("/#{idx}/#{path.relative_path}")
              elsif mode == 'delete' # delete file
                path.remove
                parent = File.dirname(path.relative_path)
                parent = '' if parent == '/'
                parent = nil if parent == '.'
                redirect!("/#{idx}#{parent}")
              elsif mode == 'edit' && path.mime_type.match(/text\/|x-empty/) # edit file
                render!(
                  'edit',
                  layout: 'app',
                  locals: default_locals.merge(contents: path.content)
                )
              elsif mode != 'raw' # render file
                revision_path = path.absolute_path(request.params['revision'])
                contents =
                  begin # attempting to render file
                    %(<div class="tilt">#{render(revision_path)}</div>)
                  rescue RuntimeError # not tilt supported
                    if path.mime_type.match(/text\//)
                      <<-EOS.gsub(/^\s+/, '')
                        <pre class="CodeRay">
                          #{CodeRay.scan_file(revision_path).encode(:html)}
                        </pre>
                      EOS
                    else
                      %(<embed class="inline-file" src="/#{idx}#{request.path_info}?mode=raw"></embed>)
                    end
                  end
                render!(
                  'file',
                  layout: 'app',
                  locals: default_locals.merge(contents: contents)
                )
              else # other file
                run! Rack::File.new(repository.root)
              end
            end
          end
        }.setup {
          views_path(File.expand_path('../views', __FILE__))
        }
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
