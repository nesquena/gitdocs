require 'thin'
require 'renee'
require 'coderay'
require 'uri'
require 'shell_tools'

module Gitdocs
  class Server
    def initialize(manager, *gitdocs)
      @manager = manager
      @gitdocs = gitdocs
    end

    def start(port = 8888)
      gds = @gitdocs
      manager = @manager
      Thin::Server.start('127.0.0.1', port) do
        use Rack::Static, :urls => ['/css', '/js', '/img', '/doc'], :root => File.expand_path("../public", __FILE__)
        run Renee {
          if request.path_info == '/'
            render! "home", :layout => 'app', :locals => {:gds => gds}
          else
            path 'settings' do
              get.render! 'settings', :layout => 'app', :locals => {:conf => manager.config}
              post do
                shares = manager.config.shares
                manager.config.global.update_attributes(request.POST['config'])
                request.POST['share'].each do |idx, share|
                  if remote_branch = share.delete('remote_branch')
                    share['remote_name'], share['branch_name'] = remote_branch.split('/', 2)
                  end
                  shares[Integer(idx)].update_attributes(share)
                end
                manager.restart
                redirect! '/settings'
              end
            end

            var :int do |idx|
              gd = gds[idx]
              halt 404 if gd.nil?
              file_path = URI.unescape(request.path_info)
              file_ext  = File.extname(file_path)
              expanded_path = File.expand_path(".#{file_path}", gd.root)
              halt 400 unless expanded_path[/^#{Regexp.quote(gd.root)}/]
              parent = File.dirname(file_path)
              parent = '' if parent == '/'
              parent = nil if parent == '.'
              locals = {:idx => idx, :parent => parent, :root => gd.root, :file_path => expanded_path}
              mode, mime = request.params['mode'], `file -I #{ShellTools.escape(expanded_path)}`.strip
              if mode == 'save' # Saving
                File.open(expanded_path, 'w') { |f| f.print request.params['data'] }
                redirect! "/" + idx.to_s + file_path
              elsif mode == 'upload'  # Uploading
                halt 404 unless file = request.params['file']
                tempfile, filename = file[:tempfile], file[:filename]
                FileUtils.mv(tempfile.path, File.expand_path(filename, expanded_path))
                redirect! "/" + idx.to_s + file_path + "/" + filename
              elsif !File.exist?(expanded_path) # edit for non-existent file
                render! "edit", :layout => 'app', :locals => locals.merge(:contents => "")
              elsif File.directory?(expanded_path)
                contents = Dir[File.join(gd.root, request.path_info, '*')]
                index_file = Dir[File.join(gd.root, request.path_info, 'README.{md,txt}')].to_a + Dir[File.join(gd.root, request.path_info, 'README')].to_a
                index_contents = unless index_file.empty?
                  Tilt.new(index_file.first).render
                else
                  nil
                end
                render! "dir", :layout => 'app', :locals => locals.merge(:contents => contents, :index_contents => index_contents, :index_file => index_file.first)
              elsif mode == 'delete' # delete file
                FileUtils.rm(expanded_path)
                redirect! "/" + idx.to_s + parent
              elsif mode == 'edit' && mime.match(%r{text/}) # edit file
                contents = File.read(expanded_path)
                render! "edit", :layout => 'app', :locals => locals.merge(:contents => contents)
              elsif mode != 'raw'
                begin # attempting to render file
                  contents = '<div class="tilt">'  + Tilt.new(expanded_path).render + '</div>'
                rescue RuntimeError => e # not tilt supported
                  contents = if mime.match(%r{text/})
                    '<pre class="CodeRay">' + CodeRay.scan_file(expanded_path).encode(:html) + '</pre>'
                  else
                    %|<iframe class="inline-frame" src="/#{idx}#{request.path_info}?mode=raw"></iframe>|
                  end
                end
                render! "file", :layout => 'app', :locals => locals.merge(:contents => contents)
              else # other file
                run! Rack::File.new(gd.root)
              end
            end
          end
        }.setup {
          views_path File.expand_path("../views", __FILE__)
        }
      end
    end
  end
end