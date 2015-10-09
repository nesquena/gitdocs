# -*- encoding : utf-8 -*-

require File.expand_path('../test_helper', __FILE__)

describe Gitdocs::Configuration do
  before do
    ShellTools.capture { Gitdocs::Initializer.initialize_database }
  end

  describe 'Config.update' do
    before do
      Gitdocs::Configuration.update(
        'start_web_frontend' => false,
        'web_frontend_port' => 9999,
        'web_frontend_host' => '0.0.0.0'
      )
    end

    it { Gitdocs::Configuration.start_web_frontend.must_equal(false) }
    it { Gitdocs::Configuration.web_frontend_port.must_equal(9999) }
    it { Gitdocs::Configuration.web_frontend_host.must_equal('0.0.0.0') }
  end
end
