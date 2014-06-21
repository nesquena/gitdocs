# -*- encoding : utf-8 -*-

class AddStartWebFrontend < ActiveRecord::Migration
  def self.up
    add_column :configs, :start_web_frontend, :boolean, default: true
  end

  def self.down
    fail
  end
end
