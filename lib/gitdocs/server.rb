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
        run Renee {
          if request.path_info == '/'
            inline!(<<-EOT, :erb, :locals => {:gds => gds})
            <html><body>
            <table>
            <% gds.each_with_index do |gd, idx| %>
              <tr><a href="/<%=idx%>"><%=gd.root%></a></tr>
            <% end %>
            </table>
            </body></html>
            EOT
          else
            var :int do |idx|
              gd = gds[idx]
              halt 404 if gd.nil?
              expanded_path = File.expand_path(".#{request.path_info}", gd.root)
              halt 400 unless expanded_path[/^#{Regexp.quote(gd.root)}/]
              halt 404 unless File.exist?(expanded_path)
              if File.directory?(expanded_path)
                run! Rack::Directory.new(gd.root)
              else
                begin
                  render! expanded_path
                rescue
                  run! Rack::File.new(gd.root)
                end
              end
            end
          end
        }
      end
    end
  end
end