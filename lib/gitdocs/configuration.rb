# -*- encoding : utf-8 -*-

require 'active_record'
require 'grit'

class Gitdocs::Configuration
  attr_reader :config_root

  def initialize(config_root = nil)
    @config_root = config_root || File.expand_path('.gitdocs', ENV['HOME'])
    FileUtils.mkdir_p(@config_root)
    ActiveRecord::Base.establish_connection(
      adapter: 'sqlite3',
      database: ENV['TEST'] ? ':memory:' : File.join(@config_root, 'config.db')
    )
    ActiveRecord::Migrator.migrate(File.expand_path('../migration', __FILE__))
    import_old_shares unless ENV['TEST']
  end

  class Share < ActiveRecord::Base
    attr_accessible :polling_interval, :path, :notification, :branch_name, :remote_name, :sync_type
  end

  class Config < ActiveRecord::Base
    attr_accessible :start_web_frontend, :web_frontend_port
  end

  # return [Boolean]
  def start_web_frontend
    global.start_web_frontend
  end

  # @return [Integer]
  def web_frontend_port
    global.web_frontend_port
  end

  # @param [String] path
  # @param [Hash] opts
  def add_path(path, opts = nil)
    path = normalize_path(path)
    path_opts = { path: path }
    path_opts.merge!(opts) if opts
    Share.new(path_opts).save!
  end

  # @param [Hash] new_config
  # @option new_config [Hash] 'config'
  # @option new_config [Array<Hash>] 'share'
  def update_all(new_config)
    global.update_attributes(new_config['config'])
    new_config['share'].each do |index, share_config|
      # Skip the share update if there is no path specified.
      next unless share_config['path'] && !share_config['path'].empty?

      # Split the remote_branch into remote and branch
      remote_branch = share_config.delete('remote_branch')
      if remote_branch
        share_config['remote_name'], share_config['branch_name'] = remote_branch.split('/', 2)
      end
      shares[index.to_i].update_attributes(share_config)
    end
  end

  # @param [String] path of the share to remove
  def remove_path(path)
    path = normalize_path(path)
    Share.where(path: path).destroy_all
  end

  # @param [Integer] id of the share to remove
  #
  # @return [true] share was deleted
  # @return [false] share does not exist
  def remove_by_id(id)
    Share.find(id).destroy
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  def clear
    Share.destroy_all
  end

  def shares
    Share.all
  end

  ##############################################################################

  private

  def global
    fail if Config.all.size > 1
    Config.create! if Config.all.empty?
    Config.all.first
  end

  def normalize_path(path)
    File.expand_path(path, Dir.pwd)
  end

  def import_old_shares
    full_path = File.expand_path('paths', config_root)
    return unless File.exist?(full_path)

    File.read(full_path).split("\n").each do |path|
      Share.find_or_create_by_path(path)
    end
  end
end
