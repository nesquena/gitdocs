class AddStartWebFrontend < ActiveRecord::Migration
  def self.up
    add_column :configs, :start_web_frontend, :boolean, :default => true
  end

  def self.down
    raise
  end
end
