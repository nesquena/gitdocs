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
        locals: { nav_state: 'settings' }
      )
    end

    post('/') do
      Configuration.update(request.POST['config'])
      Share.update_all(request.POST['share'])
      Manager.restart_synchronization
      redirect to('/')
    end

    delete('/:id') do
      id = params[:id].to_i
      halt(404) unless Share.remove_by_id(id)
      redirect to('/')
    end
  end
end
