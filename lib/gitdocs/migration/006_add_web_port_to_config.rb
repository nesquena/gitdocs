class AddWebPortToConfig < ActiveRecord::Migration
  def self.up
    add_column :configs, :web_frontend_port, :integer, default: 8888
  end

  def self.down
    fail
  end
end
