# -*- encoding : utf-8 -*-

require 'sinatra/base'
require 'haml'
require 'yaml'
require 'mimetype_fu'

module Gitdocs
  class SettingsApp < Sinatra::Base
    get('/') do
      haml(
        :settings,
        locals: { conf: settings.manager, nav_state: 'settings' }
      )
    end

    post('/') do
      settings.manager.update_all(request.POST)
      redirect to('/')
    end

    delete('/:id') do
      id = params[:id].to_i
      halt(404) unless settings.manager.remove_by_id(id)
      redirect to('/')
    end
  end
end
