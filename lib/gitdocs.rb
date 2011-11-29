require 'gitdocs/version'
require 'thread'
require 'rb-fsevent'
require 'growl'
require 'yajl'

class Gitdocs
  def initialize(root)
    @root = root
    out, status = sh_with_code "which growlnotify"
    @use_growl = status.success?
    @icon = File.expand_path("../img/icon.png", __FILE__)
  end

  def run
    info("Running gitdocs!", "Running gitdocs in `#{@root}'")
    @current_revision = `git rev-parse HEAD`.strip
    mutex = Mutex.new
    Thread.new do
      loop do
        mutex.synchronize do
          out, status = sh_with_code("git fetch --all && git merge origin/master")
          if status.success?
            changes = get_latest_changes
            unless changes.empty?
              info("Updated with #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been updated")
            end
          else
            warn("Error attempting to pull", out)
          end
          push_changes
        end
        sleep 15
      end
    end.abort_on_exception = true
    listener = FSEvent.new
    listener.watch(@root) do |directories|
      directories.uniq!
      directories.delete_if {|d| d =~ /\/\.git/}
      unless directories.empty?
        mutex.synchronize do
          push_changes
        end
      end
    end
    listener.run
  end

  def push_changes
    out, status = sh_with_code("git ls-files -o --exclude-per-directory=.gitignore | git update-index --add --stdin")
    unless sh("git status -s").strip.empty?
      sh "git commit -a -m'Auto-commit from gitdocs'" # TODO make this message nicer
      out, code = sh_with_code("git push")
      changes = get_latest_changes
      info("Pushed #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been pushed")
      error("Could not push changes", out) unless code.success?
    end
  end

  def get_latest_changes
    out = sh "git log #{@current_revision}.. --pretty='format:{\"commit\": \"%H\",%n  \"author\": \"%an <%ae>\",%n  \"date\": \"%ad\",%n  \"message\": \"%s\"%n}'"
    if out.empty?
      []
    else
      lines = []
      Yajl::Parser.new.parse(out) do |obj|
        lines << obj
      end
      @current_revision = sh("git rev-parse HEAD").strip
      lines
    end
  end

  def warn(title, msg)
    if @use_growl
      Growl.notify_warning(msg, :title => title)
    else
      Kernel.warn("#{title}: #{msg}")
    end
  end

  def info(title, msg)
    if @use_growl
      Growl.notify_ok(msg, :title => title, :icon => @icon)
    else
      puts("#{title}: #{msg}")
    end
  end

  def error(title, msg)
    if @use_growl
      Growl.notify_error(msg, :title => title)
    else
      Kernel.warn("#{title}: #{msg}")
    end
    exit
  end

  def sh(cmd)
    out, code = sh_with_code(cmd)
    code == 0 ? out : raise(out.empty? ? "Running `#{cmd}' failed. Run this command directly for more detailed output." : out)
  end

  # Run in shell, return both status and output
  # @see #sh
  def sh_with_code(cmd)
    cmd << " 2>&1"
    outbuf = ''
    outbuf = `#{cmd}`
    [outbuf, $?]
  end
end
