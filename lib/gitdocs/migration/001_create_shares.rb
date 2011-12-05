class CreateShares < ActiveRecord::Migration
  def self.up
    create_table :shares do |t|
      t.column :path, :string
      t.column :polling_interval, :double, :default => 15
      t.column :notification, :boolean, :default => true
      t.column :remote_name, :string, :default => 'origin'
      t.column :branch_name, :string, :default => 'master'
    end
  end

  def self.down
    raise
  end
end
