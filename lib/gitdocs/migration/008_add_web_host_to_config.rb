# -*- encoding : utf-8 -*-

class AddWebHostToConfig < ActiveRecord::Migration
  def self.up
    add_column :configs, :web_frontend_host, :string, default: '0.0.0.0'
  end

  def self.down
    fail
  end
end
