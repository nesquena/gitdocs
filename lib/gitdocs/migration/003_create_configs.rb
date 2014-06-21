# -*- encoding : utf-8 -*-

class CreateConfigs < ActiveRecord::Migration
  def self.up
    create_table :configs do |t|
      t.column :load_browser_on_startup, :boolean, default: true
    end
  end

  def self.down
    fail
  end
end
