# -*- encoding : utf-8 -*-

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
    end

    def start
      repositories = @repositories
      manager      = @manager
      Thin::Logging.debug = @manager.debug
      Thin::Server.start('127.0.0.1', @port) do
        use Rack::Static, urls: ['/css', '/js', '/img', '/doc'], root: File.expand_path('../public', __FILE__)
        use Rack::MethodOverride
        run Renee {
          if request.path_info == '/'
            if manager.config.shares.size == 1
              redirect! '/0'
            else
              render! 'home', layout: 'app', locals: { conf: manager.config, nav_state: 'home' }
            end
          else
            path 'settings' do
              get.render! 'settings', layout: 'app', locals: { conf: manager.config, nav_state: 'settings' }
              post do
                manager.update_all(request.POST)
                redirect! '/settings'
              end
            end

            path('search').get do
              render! 'search', layout: 'app', locals: { conf: manager.config, results: Gitdocs::Search.new(repositories).search(request.GET['q']), nav_state: nil }
            end

            path('shares') do
              post do
                Configuration::Share.create
                redirect! '/settings'
              end

              var(:int) do |id|
                delete do
                  halt(404) unless manager.remove_by_id(id)
                  redirect!('/settings')
                end
              end
            end

            var :int do |idx|
              repository = repositories[idx]

              halt 404 if repository.nil?
              file_path = URI.unescape(request.path_info)
              expanded_path = File.expand_path(".#{file_path}", repository.root)
              message_file = File.expand_path('.gitmessage~', repository.root)
              halt 400 unless expanded_path[/^#{Regexp.quote(repository.root)}/]
              parent = File.dirname(file_path)
              parent = '' if parent == '/'
              parent = nil if parent == '.'
              locals = { idx: idx, parent: parent, root: repository.root, file_path: expanded_path, nav_state: nil }
              mime = File.mime_type?(File.open(expanded_path)) if File.file?(expanded_path)
              mode = request.params['mode']
              if mode == 'meta' # Meta
                halt 200, { 'Content-Type' => 'application/json' }, [repository.file_meta(file_path).to_json]
              elsif mode == 'save' # Saving
                File.open(expanded_path, 'w') { |f| f.print request.params['data'] }
                File.open(message_file, 'w') { |f| f.print request.params['message'] } unless request.params['message'] == ''
                redirect! '/' + idx.to_s + file_path
              elsif mode == 'upload'  # Uploading
                halt 404 unless file = request.params['file']
                tempfile, filename = file[:tempfile], file[:filename]
                FileUtils.mv(tempfile.path, File.expand_path(filename, expanded_path))
                redirect! '/' + idx.to_s + file_path + '/' + filename
              elsif !File.exist?(expanded_path) && !request.params['dir'] # edit for non-existent file
                FileUtils.mkdir_p(File.dirname(expanded_path))
                FileUtils.touch(expanded_path)
                redirect!  '/' + idx.to_s + file_path + '?mode=edit'
              elsif !File.exist?(expanded_path) && request.params['dir'] # create directory
                FileUtils.mkdir_p(expanded_path)
                redirect!  '/' + idx.to_s + file_path
              elsif File.directory?(expanded_path) # list directory
                contents =  Dir[File.join(expanded_path, '*')].map { |x| Docfile.new(x) }
                rendered_readme = nil
                if readme = Dir[File.expand_path('README.{md}', expanded_path)].first
                  rendered_readme = '<h3>' + File.basename(readme) + '</h3><div class="tilt">' + render(readme) + '</div>'
                end
                render! 'dir', layout: 'app', locals: locals.merge(contents: contents, rendered_readme: rendered_readme)
              elsif mode == 'revisions' # list revisions
                revisions = repository.file_revisions(file_path)
                render! 'revisions', layout: 'app', locals: locals.merge(revisions: revisions)
              elsif mode == 'revert' # revert file
                if revision = request.params['revision']
                  File.open(message_file, 'w') { |f| f.print "Reverting '#{file_path}' to #{revision}" }
                  repository.file_revert(file_path, revision)
                end
                redirect! '/' + idx.to_s + file_path
              elsif mode == 'delete' # delete file
                FileUtils.rm(expanded_path)
                redirect! '/' + idx.to_s + parent
              elsif mode == 'edit' && (mime.match(%r{text/}) || mime.match(%r{x-empty})) # edit file
                contents = File.read(expanded_path)
                render! 'edit', layout: 'app', locals: locals.merge(contents: contents)
              elsif mode != 'raw' # render file
                revision = request.params['revision']
                expanded_path = repository.file_revision_at(file_path, revision) if revision
                begin # attempting to render file
                  contents = '<div class="tilt">' + render(expanded_path) + '</div>'
                rescue RuntimeError # not tilt supported
                  contents = if mime.match(%r{text/})
                    '<pre class="CodeRay">' + CodeRay.scan_file(expanded_path).encode(:html) + '</pre>'
                  else
                    %|<embed class="inline-file" src="/#{idx}#{request.path_info}?mode=raw"></embed>|
                  end
                end
                render! 'file', layout: 'app', locals: locals.merge(contents: contents)
              else # other file
                run! Rack::File.new(repository.root)
              end
            end
          end
        }.setup {
          views_path File.expand_path('../views', __FILE__)
        }
      end
    end

    def wait_for_start_and_open(restarting)
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
