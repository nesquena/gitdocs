class AddIndexForPath < ActiveRecord::Migration
  def self.up
    shares = Gitdocs::Configuration::Share.all.inject(Hash.new{|h,k| h[k] = []}) {|h, s| h[s.path] << s; h}
    shares.each do |path, shares|
      shares.shift
      shares.each(&:destroy) unless shares.empty?
    end
    add_index :shares, :path, :unique => true
  end
end