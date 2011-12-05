class AddRemoteBranch < ActiveRecord::Migration
  def self.up
    add_column :shares, :remote_name, :string, :default => 'origin'
    add_column :shares, :branch_name, :string, :default => 'master'
  end

  def self.down
    raise
  end
end
