module Gitdocs
  class Runner
    attr_accessor :root

    def initialize(root, opts = nil)
      @root = root
      out, status = sh_with_code "which growlnotify"
      @use_growl = opts && opts.key?(:growl) ? opts[:growl] : status.success?
      @polling_interval = opts && opts[:polling_interval] || 15
      @icon = File.expand_path("../../img/icon.png", __FILE__)
    end

    def run
      info("Running gitdocs!", "Running gitdocs in `#{@root}'")
      @current_remote   = sh_string("git config branch.`git branch | grep '^\*' | sed -e 's/\* //'`.remote", "origin")
      @current_branch   = sh_string("git branch | grep '^\*' | sed -e 's/\* //'", "master")
      @current_revision = sh("git rev-parse HEAD").strip rescue nil
      mutex = Mutex.new
      Thread.new do
        loop do
          mutex.synchronize do
            out, status = sh_with_code("git fetch --all && git merge #{@current_remote}/#{@current_branch}")
            if status.success?
              changes = get_latest_changes
              unless changes.empty?
                info("Updated with #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been updated")
              end
              push_changes
            elsif out[/CONFLICT/]
              conflicted_files = sh("git ls-files -u --full-name -z").split("\0").
                inject(Hash.new{|h, k| h[k] = []}) {|h, line|
                  parts = line.split(/\t/)
                  h[parts.last] << parts.first.split(/ /).last
                  h
                }
              warn("There were some conflicts", "#{conflicted_files.keys.map{|f| "* #{f}"}.join("\n")}")
              conflicted_files.each do |conflict, idxs|
                conflict_start, conflict_end = conflict.scan(/(.*?)(|\.[^\.]+)$/).first
                system("cd #{@root} && git show :1:#{conflict} > #{conflict_start}-original#{conflict_end}") if idxs.include?('1')
                system("cd #{@root} && git show :2:#{conflict} > #{conflict_start}-1#{conflict_end}") if idxs.include?('2')
                system("cd #{@root} && git show :3:#{conflict} > #{conflict_start}-2#{conflict_end}") if idxs.include?('3')
                system("cd #{@root} && git rm #{conflict}") or raise
              end
              push_changes
            else
              error("There was a problem synchronizing this gitdoc", "A problem occurred in #{@root}:\n#{out}")
            end
          end
          sleep @polling_interval
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
      at_exit { listener.stop }
      listener.run
    end

    def push_changes
      sh 'find . -type d -regex ``./[^.].*'' -empty -exec touch \'{}/.gitignore\' \;'
      sh 'git add .'
      # TODO make this message nicer
      sh "git commit -a -m'Auto-commit from gitdocs'" unless sh("git status -s").strip.empty?
      if @current_revision.nil? || sh('git status')[/branch is ahead/]
        out, code = sh_with_code("git push #{@current_remote} #{@current_branch}")
        if code.success?
          changes = get_latest_changes
          info("Pushed #{changes.size} change#{changes.size == 1 ? '' : 's'}", "`#{@root}' has been pushed")
        elsif @current_revision.nil?
          # ignorable
        elsif out[/\[rejected\]/]
          warn("There was a conflict in #{@root}, retrying", "")
          #error("CONFLICT Could not push changes in #{@root}", out)
          #exit
        else
          error("BAD Could not push changes in #{@root}", out)
          exit
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
    end

    # sh_string("git config branch.`git branch | grep '^\*' | sed -e 's/\* //'`.remote", "origin")
    def sh_string(cmd, default)
      val = sh(cmd).strip rescue nil
      (val.nil? || val.empty?) ? default : val
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
      outbuf = `cd "#{@root}" && #{cmd}`
      [outbuf, $?]
    end
  end
end
