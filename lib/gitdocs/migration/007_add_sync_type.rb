# -*- encoding : utf-8 -*-

class AddSyncType < ActiveRecord::Migration
  def self.up
    add_column :shares, :sync_type, :string, default: 'full'
  end

  def self.down
    fail
  end
end
