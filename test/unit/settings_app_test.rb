# -*- encoding : utf-8 -*-

ENV['RACK_ENV'] = 'test'
require File.expand_path('../test_helper', __FILE__)
require 'rack/test'

describe Gitdocs::SettingsApp do
  include Rack::Test::Methods
  def app
    Gitdocs::SettingsApp
  end

  describe 'get /' do
    before do
      Gitdocs::Configuration
        .stubs(:web_frontend_port)
        .returns(1111)
      share = stub(
        id:               :id,
        path:             :repository_path,
        polling_interval: :polling_interval,
        sync_type:        'full',
        notification:     true,
        remote_name:      'remote',
        branch_name:      'branch'
      )
      Gitdocs::Share.stubs(:all).returns([share])
      Gitdocs::Repository
        .stubs(:new)
        .with(share)
        .returns(stub(available_remotes: [:remote]))

      get '/'
    end
    specify do
      last_response.status.must_equal(200)
      last_response.body.must_include('Gitdocs')
      last_response.body.must_include('1111')
      last_response.body.must_include('repository_path')
      last_response.body.must_include('full')
      last_response.body.must_include('remote')
      last_response.body.must_include('branch')
    end
  end

  describe 'post /' do
    before do
      Gitdocs::Configuration.expects(:update).with('config_data')
      Gitdocs::Share.expects(:update_all).with('share_data')
      Gitdocs::Manager.expects(:restart_synchronization)

      post '/', config: 'config_data', share: 'share_data'
    end

    specify do
      last_response.status.must_equal(302)
      last_response.headers['Location'].must_equal('http://example.org/')
    end
  end

  describe 'delete /:id' do
    before do
      Gitdocs::Share.expects(:remove_by_id).with(1234).returns(remove_result)
      delete '/1234'
    end

    describe 'missing' do
      let(:remove_result) { false }
      specify { last_response.status.must_equal(404) }
    end

    describe 'exists' do
      let(:remove_result) { true }
      specify do
        last_response.status.must_equal(302)
        last_response.headers['Location'].must_equal('http://example.org/')
      end
    end
  end
end
