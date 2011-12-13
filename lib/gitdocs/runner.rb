module Gitdocs
  class Runner
    include ShellTools

    attr_reader :root, :listener

    def initialize(share)
      @share = share
      @root  = share.path
      @polling_interval = share.polling_interval
      @icon = File.expand_path("../../img/icon.png", __FILE__)
    end

    SearchResult = Struct.new(:file, :context)
    def search(term)
      results = []
      sh_string("git grep #{ShellTools.escape(term)}").scan(/(.*?):([^\n]*)/) do |(file, context)|
        results << SearchResult.new(file, context)
      end
      results
    end

    def run
      return false unless self.valid?
      out, status = sh_with_code "which growlnotify"
      @use_growl = @share.notification && status.success?
      @current_remote   = @share.remote_name
      @current_branch   = @share.branch_name
      @current_revision = sh_string("git rev-parse HEAD")
      mutex = Mutex.new

      info("Running gitdocs!", "Running gitdocs in `#{@root}'")

      # Pull changes from remote repository
      syncer = proc do
        EM.defer(proc do
          mutex.synchronize { sync_changes }
        end, proc do
          EM.add_timer(@polling_interval) {
            syncer.call
          }
        end)
      end
      syncer.call
      # Listen for changes in local repository

      EM.defer(proc{
        listener = Guard::Listener.select_and_init(@root, :watch_all_modifications => true)
        listener.on_change { |directories|
          directories.uniq!
          directories.delete_if {|d| d =~ /\/\.git/}
          unless directories.empty?
            EM.next_tick do
              EM.defer(proc {
                mutex.synchronize { push_changes }
              }, proc {} )
            end
          end
        }
        listener.start
      }, proc{EM.stop_reactor})
    end

    def clear_state
      @state = nil
    end

    def sync_changes
      out, status = sh_with_code("git fetch --all && git merge #{@current_remote}/#{@current_branch}")
      if status.success?
        changes = get_latest_changes
        unless changes.empty?
          author_list = changes.inject(Hash.new{|h, k| h[k] = 0}) {|h, c| h[c['author']] += 1; h}.to_a.sort{|a,b| b[1] <=> a[1]}.map{|(name, count)| "* #{name} (#{count} change#{count == 1 ? '' : 's'})"}.join("\n")
          info("Updated with #{changes.size} change#{changes.size == 1 ? '' : 's'}", "In `#{@root}':\n#{author_list}")
        end
        push_changes
      elsif out[/CONFLICT/]
        conflicted_files = sh("git ls-files -u --full-name -z").split("\0").
          inject(Hash.new{|h, k| h[k] = []}) {|h, line|
            parts = line.split(/\t/)
            h[parts.last] << parts.first.split(/ /)
            h
          }
        warn("There were some conflicts", "#{conflicted_files.keys.map{|f| "* #{f}"}.join("\n")}")
        conflicted_files.each do |conflict, ids|
          conflict_start, conflict_end = conflict.scan(/(.*?)(|\.[^\.]+)$/).first
          ids.each do |(mode, sha, id)|
            author =  " original" if id == "1"
            system("cd #{@root} && git show :#{id}:#{conflict} > '#{conflict_start} (#{sha[0..6]}#{author})#{conflict_end}'")
          end
          system("cd #{@root} && git rm #{conflict}") or raise
        end
        push_changes
      elsif sh_string("git remote").nil? # no remote to pull from
        # Do nothing, no remote repo yet
      else
        error("There was a problem synchronizing this gitdoc", "A problem occurred in #{@root}:\n#{out}")
      end
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

    IGNORED_FILES = ['.gitignore']
    # dir_files("some/dir") => [<Docfile>, <Docfile>]
    def dir_files(dir)
      dir_path = File.expand_path(dir, @root)
      files = {}
      ls_files = sh_string("git ls-files").split("\n").map { |f| Docfile.new(f) }
      ls_files.select { |f| f.within?(dir, @root) }.each do |f|
        path = File.expand_path(f.parent, root)
        files[path] ||= Docdir.new(path)
        files[path].files << f unless IGNORED_FILES.include?(f.name)
      end
      files.keys.each { |f| files[f].parent = files[File.dirname(f)] }
      files[dir_path]
    end

    def file_meta(file)
      file = file.gsub(%r{^/}, '')
      author, modified = sh_string("git log --format='%aN|%ai' -n1 #{ShellTools.escape(file)}").split("|")
      modified = Time.parse(modified.sub(' ', 'T')).utc.iso8601
      { :author => author, :modified => modified }
    end

    def valid?
      out, status = sh_with_code "git status"
      status.success?
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
    def sh_string(cmd, default=nil)
      val = sh(cmd).strip rescue nil
      (val.nil? || val.empty?) ? default : val
    end

    # Run in shell, return both status and output
    # @see #sh
    def sh_with_code(cmd)
      ShellTools.sh_with_code(cmd, @root)
    end
  end
end
