# -*- encoding : utf-8 -*-

require 'sinatra/base'
require 'coderay'
require 'uri'
require 'haml'
require 'mimetype_fu'
require 'tilt'

module Gitdocs
  class BrowserApp < Sinatra::Base
    set :haml, format: :html5

    get('/') do
      if settings.repositories.size == 1
        redirect to('/0/')
      else
        haml(
          :home,
          locals: {
            shares:    settings.repositories,
            nav_state: 'home'
          }
        )
      end
    end

    get('/search') do
      haml(
        :search,
        locals: {
          results: Gitdocs::Search.new(settings.repositories).search(params[:q]),
          nav_state: nil
        }
      )
    end

    helpers do
      # @return [Integer]
      def id
        @id ||= params[:id].to_i
      end

      # @return [Gitdocs::Repository::Path]
      def path
        halt(404) unless settings.repositories[id]
        @path ||= Gitdocs::Repository::Path.new(
          settings.repositories[id], URI.unescape(params[:splat].first)
        )
      end
    end

    get('/:id*') do
      default_locals = {
        idx:       id,
        root:      settings.repositories[id].root,
        nav_state: nil
      }

      case params[:mode]
      when 'meta'
        begin
          content_type :json
          path.meta.to_json
        rescue
          halt(404)
        end
      when 'edit'
        halt(404) unless path.text?
        haml(
          :edit,
          locals: default_locals.merge(contents: path.content)
        )
      when 'revisions'
        haml(
          :revisions,
          locals: default_locals.merge(revisions: path.revisions)
        )
      when 'raw'
        send_file(path.absolute_path)
      else
        if path.directory?
          rendered_readme =
            if path.readme_path
              <<-EOS.gusb(/^\s+/, '')
                <h3>#{File.basename(path.readme_path)}</h3>
                <div class="tilt">#{render(path.readme_path)}</div>
              EOS
            end
          haml(
            :dir,
            locals: default_locals.merge(
              contents:        path.file_listing,
              rendered_readme: rendered_readme
            )
          )
        else
          revision_path = path.absolute_path(params[:revision])
          contents =
            begin # Attempt to render with Tilt
              %(<div class="tilt">#{Tilt.new(revision_path).render}</div>)
            rescue LoadError, RuntimeError # No tilt support
              if path.text?
                <<-EOS.gsub(/^\s+/, '')
                  <pre class="CodeRay">
                    #{CodeRay.scan_file(revision_path).encode(:html)}
                  </pre>
                EOS
              else
                %(<embed class="inline-file" src="/#{id}#{request.path_info}?mode=raw"></embed>)
              end
            end
          haml(
            :file,
            locals: default_locals.merge(contents: contents)
          )
        end
      end
    end

    post('/:id*') do
      redirect_path =
        if params['file']
          file = params['file']
          halt(404) unless file
          tempfile = file[:tempfile]
          filename = file[:filename]
          FileUtils.mv(tempfile.path, path.absolute_path)
          "/#{id}/#{path.relative_path}/#{filename}"
        elsif params[:filename]
          path.join(params[:filename])
          if params[:new_file]
            path.touch
            "/#{id}/#{path.relative_path}?mode=edit"
          elsif params[:new_directory]
            path.mkdir
            "/#{id}/#{path.relative_path}"
          else
            halt(400)
          end
        else
          halt(400)
        end
      redirect to(redirect_path)
    end

    put('/:id*') do
      redirect_path =
        if params[:revision] # revert
          path.revert(params[:revision])
          "/#{id}/#{path.relative_path}"
        elsif params[:data] && params[:message] # save
          path.write(params[:data], params[:message])
          "/#{id}/#{path.relative_path}"
        else
          # No valid inputs, do nothing and redirect.
          "/#{id}/#{path.relative_path}"
        end
      redirect to(redirect_path)
    end

    delete('/:id*') do
      path.remove
      parent = File.dirname(path.relative_path)
      parent = '' if parent == '/'
      parent = nil if parent == '.'
      redirect to("/#{id}#{parent}")
    end
  end
end
