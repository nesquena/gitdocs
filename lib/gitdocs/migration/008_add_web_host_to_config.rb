# -*- encoding : utf-8 -*-

class AddWebHostToConfig < ActiveRecord::Migration
  def self.up
    add_column :configs, :web_frontend_host, :string, default: '127.0.0.1'
  end

  def self.down
    fail
  end
end
