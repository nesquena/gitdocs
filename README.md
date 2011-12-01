# Gitdocs

Collaborate on files and docs through a shared git repository. gitdocs will automatically push changes to the repo as well as pull in changes.
This allows any git repo to be used as a collaborative task list or wiki for a team. 
You can also start a web front-end allowing the repo to be accessed through a browser.

## Installation

Install the gem:

```
gem install gitdocs
```

If you have Growl installed on Max OSX, you'll probably want to run:

```
brew install growlnotify
```

to enable Growl support (other platforms coming soon).

## Usage

Gitdocs is centered around 'watching' any number of directories for changes and keeping them automatically synced. You can either add
existing git directories for monitoring or have gitdocs pull down a repository to monitor.

You can add existing folders to watch:

```
gitdocs add my/path/to/watch
```

or instruct gitdocs to fetch a remote repository and keep it synced with:

```
gitdocs create local/path/for/repo git@github.com:user/some/remote/repo.git
```

This will clone the remote repo and begin monitoring the local path. You can remove and clear monitored paths as well:

```
gitdocs rm my/path/to/watch
gitdocs clear
```

You need to start gitdocs in order for the monitoring to work:

```
gitdocs start
```

If the start command fails, you can run again with a debug flag:

```
gitdocs start -D
```

and gitdocs can be easily stopped and restarted:

```
gitdocs stop
gitdocs restart
```

For an overview of gitdocs current status, run:

```
gitdocs status
```

Once gitdocs has been started and is monitoring the correct directories, simply start editing or adding files to your
designated git repos. Changes will be automatically pushed and pulled to your local repos.

To explore the repos in your browser, simply start the server:

```
gitdocs serve
```

and then visit `http://localhost:8888` for access to all your docs in the browser.

## Planned Features

Gitdocs is a young project but we have big plans for it including:

 - A web UI for easy uploading, and editing of files (in addition to viewing)
 - Local-area peer-to-peer syncing, avoiding 'polling' in cases where we can.
 - Click-to-share instant access granting using a local tunnel or other means.
 - Better conflict-resolution behavior (maintains both versions of a file)
 - Support for linux and windows (coming soon)
