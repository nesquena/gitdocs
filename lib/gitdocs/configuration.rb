module Gitdocs
  class Configuration
    attr_reader :config_root

    def initialize(config_root = nil)
      @config_root = config_root || File.expand_path(".gitdocs", ENV["HOME"])
      FileUtils.mkdir_p(@config_root)
    end

    # @config.paths => ['my/path/1', 'my/path/2']
    def paths
      self.read_file('paths').split("\n")
    end

    def paths=(paths)
      self.write_file('paths', paths.uniq.join("\n"))
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

    protected

    # Read file from gitdocs repo
    # @config.read_file('paths')
    def read_file(name)
      full_path = File.expand_path(name, @config_root)
      File.exist?(full_path) ? File.read(full_path) : ''
    end

    # Writes configuration file
    # @config.write_file('paths', '...')
    def write_file(name, content)
      File.open(File.expand_path(name, @config_root), 'w') { |f| f.puts content }
    end
  end
end