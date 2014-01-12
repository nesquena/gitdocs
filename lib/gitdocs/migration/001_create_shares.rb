class CreateShares < ActiveRecord::Migration
  def self.up
    create_table :shares do |t|
      t.column :path, :string
      t.column :polling_interval, :double, default: 15
      t.column :notification, :boolean, default: true
    end
  end

  def self.down
    fail
  end
end
