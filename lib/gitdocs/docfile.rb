module Gitdocs
  class Docfile
    attr_reader :parent, :path, :name, :author, :modified

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
  end

  class Docdir < Docfile
    attr_accessor :subdirs
    attr_accessor :files

    def initialize(path)
      super
      @subdirs = []
      @files = []
    end

    def items
      subdirs + files
    end

    def parent=(dir)
      dir.subdirs.push(self) if dir
    end
  end
end