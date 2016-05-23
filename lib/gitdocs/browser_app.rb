# -*- encoding : utf-8 -*-

require 'sinatra/base'
require 'uri'
require 'haml'
require 'mimetype_fu'
require 'gitdocs/rendering_helper'

module Gitdocs
  class BrowserApp < Sinatra::Base
    set :haml, format: :html5

    helpers RenderingHelper

    helpers do
      # @return [Integer]
      def id
        @id ||= params[:id].to_i
      end

      # @return [Gitdocs::Repository::Path]
      def repository
        @repository ||= Repository.new(Share.find(id))
      end

      # @return [Gitdocs::Repository::Path]
      def path
        halt(404) unless repository
        @path ||= Repository::Path.new(
          repository, URI.decode(params[:splat].first)
        )
      end
    end

    get('/') do
      if Share.all.count == 1
        redirect to("/#{Share.first.id}/")
      else
        haml(:home, locals: { nav_state: 'home' })
      end
    end

    get('/search') do
      haml(
        :search,
        locals: {
          results:   Search.search(params[:q]),
          nav_state: nil
        }
      )
    end

    get('/:id*') do
      default_locals = {
        root:      repository.root,
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
          haml(
            :dir,
            locals: default_locals.merge(
              contents:        path.file_listing,
              rendered_readme: file_content_render(path.readme_path)
            )
          )
        else
          haml(
            :file,
            locals: default_locals.merge(
              contents: file_content_render(
                path.absolute_path(params[:revision])
              )
            )
          )
        end
      end
    end

    post('/:id*') do
      redirect_path =
        if params[:file] # upload
          path.join(params[:file][:filename])
          path.mv(params[:file][:tempfile].path)
          "/#{id}/#{path.relative_path}"
        elsif params[:filename] # add file/directory
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
      commit_message =
        if params[:revision] # revert
          path.revert(params[:revision])
          "Reverting '#{path.relative_path}' to #{params[:revision]}"
        elsif params[:data] && params[:message] # save
          path.write(params[:data])
          params[:message]
        end
      repository.write_commit_message(commit_message)
      redirect to("/#{id}/#{path.relative_path}")
    end

    delete('/:id*') do
      path.remove
      redirect to("/#{id}/#{path.relative_dirname}")
    end
  end
end
