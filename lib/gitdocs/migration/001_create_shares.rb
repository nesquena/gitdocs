class CreateShares < ActiveRecord::Migration
  def self.up
    create_table :shares do |t|
      t.column :path, :string
      t.column :polling_interval, :integer, :default => 15
      t.column :notifications, :boolean, :default => true
    end
  end

  def self.down
    raise
  end
end
