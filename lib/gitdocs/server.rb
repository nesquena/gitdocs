require 'thin'
require 'renee'

module Gitdocs
  class Server
    def initialize(*gitdocs)
      @gitdocs = gitdocs
    end

    def start(port = 8888)
      gds = @gitdocs
      Thin::Server.start('127.0.0.1', port) do
        use Rack::Static, :urls => ['/css', '/img', '/doc'], :root => File.expand_path("../public", __FILE__)
        run Renee {
          if request.path_info == '/'
            render! "home", :layout => 'app', :locals => {:gds => gds}
          else
            var :int do |idx|
              gd = gds[idx]
              halt 404 if gd.nil?
              expanded_path = File.expand_path(".#{request.path_info}", gd.root)
              halt 400 unless expanded_path[/^#{Regexp.quote(gd.root)}/]
              halt 404 unless File.exist?(expanded_path)
              parent = File.dirname(request.path_info)
              parent = '' if parent == '/'
              parent = nil if parent == '.'
              locals = {:idx => idx, :parent => parent, :root => gd.root, :file_path => expanded_path}
              if File.directory?(expanded_path)
                contents = Dir[File.join(gd.root, request.path_info, '*')]
                render! "dir", :layout => 'app', :locals => locals.merge(:contents => contents)
              elsif request.params['mode'] != 'raw' && `file -I #{expanded_path}`.strip.match(%r{text/}) # render file
                contents = Tilt.new(expanded_path).render rescue "<pre>#{File.read(expanded_path)}</pre>"
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