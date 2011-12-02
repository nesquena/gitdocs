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
              if File.directory?(expanded_path)
                contents = Dir[File.join(gd.root, request.path_info, '*')]
                #run! Rack::Directory.new(gd.root)
                parent = File.dirname(request.path_info)
                parent = '' if parent == '/'
                parent = nil if parent == '.'
                render! "dir", :layout => 'app', :locals => {:contents => contents, :idx => idx, :parent => parent, :root => gd.root}
              else
                begin
                  render! expanded_path
                rescue
                  run! Rack::File.new(gd.root)
                end
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