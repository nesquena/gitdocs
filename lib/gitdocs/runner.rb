module Gitdocs
  class Runner
    attr_accessor :root

    def initialize(root, opts = nil)
      @root = root
      out, status = sh_with_code "which growlnotify"
      @use_growl = opts && opts.key?(:growl) ? opts[:growl] : status.success?
      @polling_interval = opts && opts[:polling_interval] || 15
      @icon = File.expand_path("../img/icon.png", __FILE__)
    end

    def run
      info("Running gitdocs!", "Running gitdocs in `#{@root}'")
      @current_revision = sh("git rev-parse HEAD").strip rescue nil
      mutex = Mutex.new
      Thread.new do
        loop do
          mutex.synchronize do
            begin
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
            rescue Exception
              error("There was an error", $!.message) rescue nil
            end
          end
          sleep @polling_interval
        end
      end
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
      at_exit { listener.stop }
      listener.run
    end

    def push_changes
      sh 'find . -type d -regex ``./[^.].*'' -empty -exec touch \'{}/.gitignore\' \;'
      sh 'git add .'
      # TODO make this message nicer
      sh "git commit -a -m'Auto-commit from gitdocs'" unless sh("git status -s").strip.empty?
      if @current_revision.nil?
        out, code = sh_with_code("git push origin master")
        if code.success?
          changes = get_latest_changes
          info("Pushed #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been pushed")
        else
          error("Could not push changes", out)
        end
      elsif sh('git status')[/branch is ahead/]
        out, code = sh_with_code("git push")
        if code.success?
          changes = get_latest_changes
          info("Pushed #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been pushed")
        else
          error("Could not push changes", out)
        end
      end
    end

    def get_latest_changes
      if @current_revision
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
      else
        []
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
      raise
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
      outbuf = `cd #{@root} && #{cmd}`
      [outbuf, $?]
    end
  end
end