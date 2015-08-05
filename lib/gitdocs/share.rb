# -*- encoding : utf-8 -*-

require 'pathname'
require 'active_record'

# @!attribute path
#   @return [String]
# @!attribute polling_interval
#   @return [Double] defaults to 15.0
# @!attribute notification
#   @return [Boolean] default to true
# @!attribute remote_name
#   @return [String] default to 'origin'
# @!attribute remote_branch
#   @return [String] default to 'master'
# @attribute sync_type
#   @return ['full','fetch']
class Gitdocs::Share < ActiveRecord::Base
  # @return [Array<String>]
  def self.paths_to_sync
    all.map(&:path)
  end

  # Return all the shares which contain the specified paths.
  #
  # @param [Array<String>] paths
  # @return [Array<Share>]
  def self.which_include(paths)
    all.select do |share|
      # Just in case the path of the share is a symlink. We want to find the
      # real path before comparing it to the include paths, because the paths
      # from Guard::Listen will re real paths.
      realpath =
        if File.exist?(share.path)
          Pathname.new(share.path).realpath.to_s
        else
          share.path
        end
      paths.any? { |x| x.start_with?(realpath) }
    end
  end

  # @return [Array<Share>]
  def self.which_need_fetch
    all
  end

  # @param [String] path
  # @return [Boolean]
  def self.create_by_path!(path)
    new(path: File.expand_path(path)).save!
  end

  # @param [Hash] updated_shares
  # @return [void]
  def self.update_all(updated_shares)
    updated_shares.each do |index, share_config|
      # Skip the share update if there is no path specified.
      next unless share_config['path'] && !share_config['path'].empty?

      # Split the remote_branch into remote and branch
      remote_branch = share_config.delete('remote_branch')
      share_config['remote_name'], share_config['branch_name'] =
        remote_branch.split('/', 2) if remote_branch

      all[index.to_i].update_attributes(share_config)
    end
    nil
  end

  # @param [Integer] id of the share to remove
  #
  # @return [true] share was deleted
  # @return [false] share does not exist
  def self.remove_by_id(id)
    find(id).destroy
    true
  rescue ActiveRecord::RecordNotFound
    false
  end

  # @param [String] path of the share to remove
  # @return [void]
  def self.remove_by_path(path)
    where(path: File.expand_path(path)).destroy_all
  end
end
