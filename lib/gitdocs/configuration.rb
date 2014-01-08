require 'active_record'
require 'grit'

module Gitdocs
  class Configuration
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
      attr_accessible :polling_interval, :path, :notification, :branch_name, :remote_name

      def available_remotes
        repo = Grit::Repo.new(path)
        repo.remotes.map { |r| r.name }
      rescue
        nil
      end

      def available_branches
        repo = Grit::Repo.new(path)
        repo.heads.map { |r| r.name }
      rescue
        nil
      end
    end

    class Config < ActiveRecord::Base
      attr_accessible :load_browser_on_startup, :start_web_frontend, :web_frontend_port
    end

    def add_path(path, opts = nil)
      path = normalize_path(path)
      path_opts = { path: path }
      path_opts.merge!(opts) if opts
      Share.new(path_opts).save!
    end

    def remove_path(path)
      path = normalize_path(path)
      Share.where(path: path).destroy_all
    end

    def clear
      Share.destroy_all
    end

    def shares
      Share.all
    end

    def global
      fail if Config.all.size > 1
      Config.create! if Config.all.empty?
      Config.all.first
    end

    def normalize_path(path)
      File.expand_path(path, Dir.pwd)
    end

    private
    def import_old_shares
      full_path = File.expand_path('paths', config_root)
      if File.exist?(full_path)
        File.read(full_path).split("\n").each { |path| Share.find_or_create_by_path(path) }
      end
    end
  end
end
