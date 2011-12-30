module Gitdocs
  class Docfile
    attr_accessor :parent
    attr_reader :path, :name

    def initialize(path)
      @path = path
      @parent = File.dirname(path)
      @name = File.basename(path)
    end

    # within?("parent", "/root/path") => "/root/path/parent"
    def within?(dir, root)
      expanded_root = File.expand_path(dir, root)
      File.expand_path(@parent, root) == expanded_root ||
        File.expand_path(@path, root).include?(expanded_root)
    end

    def dir?
      File.directory?(@path)
    end
  end
end