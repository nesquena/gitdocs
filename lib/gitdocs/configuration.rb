require 'active_record'

module Gitdocs
  class Configuration
    attr_reader :config_root

    def initialize(config_root = nil)
      @config_root = config_root || File.expand_path(".gitdocs", ENV["HOME"])
      FileUtils.mkdir_p(@config_root)
      ActiveRecord::Base.establish_connection(
        :adapter => 'sqlite3',
        :database => ENV["TEST"] ? ':memory:' : File.join(@config_root, 'config.db')
      )
      ActiveRecord::Migrator.migrate(File.expand_path("../migration", __FILE__))
      import_old_shares unless ENV["TEST"]
    end

    class Share < ActiveRecord::Base
      attr_accessible :polling_interval, :path, :notification
    end

    def add_path(path)
      Share.new(path)
    end

    def shares
      Share.all
    end

    def paths
      read_file('paths').split("\n")
    end

    def paths=(paths)
      write_file('paths', paths.uniq.join("\n"))
    end

    # @config.add_path('my/path/1')
    def add_path(path)
      path = normalize_path(path)
      self.paths += [path]
      path
    end

    # @config.remove_path('my/path/1')
    def remove_path(path)
      path = normalize_path(path)
      self.paths -= [path]
      path
    end

    def normalize_path(path)
      File.expand_path(path, Dir.pwd)
    end

    private
    def read_file(name)
      full_path = File.expand_path(name, @config_root)
      File.exist?(full_path) ? File.read(full_path) : ''
    end

    def write_file(name, content)
      File.open(File.expand_path(name, @config_root), 'w') { |f| f.puts content }
    end

    def import_old_shares
      paths.each { |path| Share.find_or_create_by_path(path) }
    end
  end
end
