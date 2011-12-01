# Gitdocs

Collaborate on files and docs through a shared git repository. gitdocs will automatically push changes to the repo as well as pull in changes.
This allows any git repo to be used as a collaborative task list or wiki for a team.
You can also start a web front-end allowing the repo to be accessed through a browser.

**Note:** Right now, gitdocs only supports Mac OSX using fsevent. Linux and windows support are coming very soon, so check back here again.

## Why Gitdocs?

Why should you use gitdocs for your file and doc sharing needs?

 * Simple - gitdocs is the simplest thing that can possibly work
 * Secure - gitdocs simply uses git (and existing providers like github) to store your data safely.
 * Versatile - share task lists, code snippets, images, files or just use it as a wiki (with our web front-end)

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

## Hosted Repos

The best part of using gitdocs to store all your files is what you get for free for using git. There are
plenty of great git hosting providers to safely store your data and you can trust the data is stored securely.

If you want a private repo to use with gitdocs, we recommend you check out [BitBucket](https://bitbucket.org/) which
provides free private git repos after registration. Simply login, add a new private repo and then
add the repo to your gitdocs monitored folders. Voila! Hosted and secure storage of all your data.

## Planned Features

Gitdocs is a young project but we have big plans for it including:

 - A web front-end UI for file uploading and editing of files (with rich text editor and syntax highlighting)
 - Local-area peer-to-peer syncing, avoid 'polling' in cases where we can using a messaging protocol.
 - Click-to-share instant access granting file access to users using a local tunnel or other means.
 - Better conflict-resolution behavior on updates (maintain both versions of a file)
 - Support for linux and windows platforms (coming soon), and maybe android and iOS as well?

## Prior Projects

Gitdocs is a fresh project that we spiked on in a few days time. Our primary goals are to keep the code as simple as possible,
but provide the features that makes dropbox great. If you are interested in other Dropbox alternatives, be sure to checkout our notes below:

 * [SparkleShare](http://sparkleshare.org/) is an open source, self-hosted Dropbox alternative. Nice project and a great alternative but has a lot of dependencies,
   more complex codebase, and lacks some of the features we have planned for gitdocs in the near future.
 * [DVCS-Autosync](http://mayrhofer.eu.org/dvcs-autosync) is a project to create an open source replacement for Dropbox based on distributed version control systems.
   Very similar project but again we have features planned that are out of scope (local tunnel file sharing, complete web ui for browsing, uploading and editing).
 * [Lipsync](https://github.com/philcryer/lipsync) is another similar project. We haven't looked at this too closely, but thought we would mention it in this list.

If any other open-source dropbox alternatives are available, we would love to hear about them so let us know!
