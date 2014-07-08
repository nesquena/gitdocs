# -*- encoding : utf-8 -*-

class Gitdocs::Repository::Path
  attr_reader :relative_path

  # @param [Gitdocs::Repository] repository
  # @param [String] relative_path
  def initialize(repository, relative_path)
    @repository    = repository
    @relative_path = relative_path.gsub(/^\//, '')
    @absolute_path = File.join(
      File.absolute_path(@repository.root), @relative_path
    )
  end

  # Write the content to the path, create any necessary directories.
  #
  # @param [String] content
  # @param [String] commit_message
  def write(content, commit_message)
    FileUtils.mkdir_p(File.dirname(@absolute_path))
    File.open(@absolute_path, 'w') { |f| f.puts(content) }

    @repository.write_commit_message(commit_message)
  end

  def touch
    FileUtils.mkdir_p(File.dirname(@absolute_path))
    FileUtils.touch(@absolute_path)
  end

  def mkdir
    FileUtils.mkdir_p(@absolute_path)
  end

  def remove
    return nil unless File.file?(@absolute_path)
    FileUtils.rm(@absolute_path)
  end

  # @return [Boolean]
  def text?
    return false unless File.file?(@absolute_path)
    mime_type = File.mime_type?(File.open(@absolute_path))
    !!(mime_type =~ /text\/|x-empty/)
  end

  # Returns file meta data based on relative file path
  #
  # @example
  #  meta
  #  => { :author => "Nick", :size => 1000, :modified => ... }
  #
  # @raise [RuntimeError] if the file is not found in any commits
  #
  # @return [Hash<Symbol=>String,Integer,Time>] the author, size and
  #   modification date of the file
  def meta
    commit = @repository.last_commit_for(@relative_path)

    # FIXME: This should actually just return an empty hash
    fail("File #{@relative_path} not found") unless commit

    {
      author:   commit.author[:name],
      size:     total_size,
      modified: commit.author[:time]
    }
  end

  def exist?
    File.exist?(@absolute_path)
  end

  def directory?
    File.directory?(@absolute_path)
  end

  def absolute_path(ref = nil)
    return @absolute_path unless ref

    blob    = @repository.blob_at(@relative_path, ref)
    content = blob ? blob.text : ''
    tmp_path = File.expand_path(File.basename(@relative_path), Dir.tmpdir)
    File.open(tmp_path, 'w') { |f| f.puts content }
    tmp_path
  end

  def readme_path
    return nil unless directory?
    Dir.glob(File.join(@absolute_path, 'README.{md}')).first
  end

  DirEntry = Struct.new(:name, :is_directory)

  # @return [Array<DirEntry>] entries in the directory
  #   * excluding any git related directories
  #   * sorted by filename, ignoring any leading '.'s
  def file_listing
    return nil unless directory?

    Dir.glob(File.join(@absolute_path, '{*,.*}'))
      .reject  { |x| x.match(/\/\.(\.|git|gitignore|gitmessage~)?$/) }
      .sort_by { |x| File.basename(x).sub(/^\./, '') }
      .map     { |x| DirEntry.new(File.basename(x), File.directory?(x)) }
  end

  def content
    return nil unless File.file?(@absolute_path)
    File.read(@absolute_path)
  end

  # Returns the revisions available for a particular file
  #
  # @param [String] file
  #
  # @return [Array<Hash>]
  def revisions
    @repository.commits_for(@relative_path, 100).map do |commit|
      {
        commit:  commit.oid[0, 7],
        subject: commit.message.split("\n")[0],
        author:  commit.author[:name],
        date:    commit.author[:time]
      }
    end
  end

  # Revert file to the specified ref
  #
  # @param [String] ref
  def revert(ref)
    return unless ref

    blob = @repository.blob_at(@relative_path, ref)
    # Silently fail if the file/ref do not existing in the repository.
    # Which is consistent with the original behaviour.
    # TODO: should consider throwing an exception on this condition
    return unless blob

    write(blob.text, "Reverting '#{@relative_path}' to #{ref}")
  end

  #############################################################################

  private

  def total_size
    size =
      if File.directory?(@absolute_path)
        Dir[File.join(@absolute_path, '**', '*')].reduce(0) do |size, filename|
          File.symlink?(filename) ? size : size + File.size(filename)
        end
      else
        File.symlink?(@absolute_path) ? 0 : File.size(@absolute_path)
      end

    # HACK: A value of 0 breaks the table sort for some reason
    return -1 if size == 0

    size
  end
end
