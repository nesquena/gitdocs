# Gitdocs

Open-source dropbox alternative powered by git. Collaborate on files and tasks without any extra hassle.
gitdocs will automatically keep everyone's repos in sync by pushing and pulling changes.
This allows any git repo to be used as a collaborative task list, file share, or wiki for a team.
Supports a web front-end allowing each repo to be accessed through your browser.

**Note:** Gitdocs uses [joshbuddy-guard](https://github.com/joshbuddy/guard) for file system monitoring. This
means that gitdocs works on Mac OSX, Linux and Windows. That being said, we have only currently
tested on Mac OSX and our notifications are still mac-only. Stay tuned.

## Why?

Why should you use gitdocs for your file and doc sharing needs?

 * **Open** - gitdocs is entirely open-source under the MIT license
 * **Simple** - gitdocs is the simplest thing that works in both setup and usage
 * **Secure** - gitdocs leverages git (and existing providers like github) to store your data safely.
 * **Versatile** - share task lists, code snippets, images, files or just use it as a wiki (with our web front-end)
 * **Portable** - access your files anywhere you can use git (with upcoming cross-platform support)

The best part is that giving this a try is quick and easy.

## Quick Start

Gitdocs monitors any number of directories for changes and keeps them automatically synced. You can either add
existing git directories to be watched or have gitdocs pull down a repository for you.

There are plenty of great git hosting providers to safely store your data and you can trust the data is stored securely.
If you want a private repo to use with gitdocs, we recommend you check out [BitBucket](https://bitbucket.org/) which
provides free private git repos after registration.

To get started with gitdocs and a secure private bitbucket repo:

 - `gem install gitdocs`
 - `gitdocs start`
 - Login to [BitBucket](https://bitbucket.org/) and add a new private repo named 'docs'
 - Setup your SSH Key under [Account](https://bitbucket.org/account/) for ssh access
 - `gitdocs create ~/Documents/gitdocs git@bitbucket.org:username/docs.git`

There you go! Now just start adding and editing files within the directory and they will be automatically
synchronized across all gitdocs-enabled clients.

## Installation

Requires ruby and rubygems. Install as a gem:

```
gem install gitdocs
```

If you have Growl installed on Max OSX, you'll probably want to run:

```
brew install growlnotify
```

to enable Growl support (other platforms coming soon).

## Usage

### Starting Gitdocs

You need to start gitdocs in order for the monitoring to work:

```
gitdocs start
```

If the start command fails, you can check the logs in `~/.gitdocs/log` or run again with the debug flag:

```
gitdocs start -D
```

Once gitdocs has been started and is monitoring the correct directories, simply start editing or adding files to your
designated git repos and changes will be automatically pushed. Gitdocs can be easily stopped or restarted:

```
gitdocs stop
gitdocs restart
```

For an overview of gitdocs current status, run:

```
gitdocs status
```

### Monitoring Shares

You can add existing folders to watch:

```
gitdocs add my/path/to/watch
```

or instruct gitdocs to fetch a remote share and keep it synced with:

```
gitdocs create local/path/for/repo git@github.com:user/some/remote/repo.git
```

This will clone the remote repo and begin monitoring the local path. You can remove and clear monitored paths as well:

```
gitdocs rm my/path/to/watch
gitdocs clear
```

### Web Front-end

Gitdocs come with a handy web front-end that is available.

<a href="http://i.imgur.com/IMwqN.png">
  <img src="http://i.imgur.com/IMwqN.png" width="250" />
</a>
<a href="http://i.imgur.com/0wVyB.png">
  <img src="http://i.imgur.com/0wVyB.png" width="250" />
</a>
<a href="http://i.imgur.com/Ijyo9.png">
  <img src="http://i.imgur.com/Ijyo9.png" width="250" />
</a>

This browser front-end supports the following features:

 * Explore the files within all your shares
 * View source files in your shares with code syntax highlighting
 * View text files in your shares with smart formatting (markdown, textile)
 * View any file in your shares that can be rendered inline (pdf, images, et al)
 * Edit and update text files using a text editor
 * Upload and create new files within your shares
 * Manage share settings and other configuration options

To check out the front-end, simply visit `http://localhost:8888` whenever gitdocs is running.

### Conflict Resolution

Proper conflict resolution is an important part of any good doc and file collaboration tool.
In most cases, git does a good job of handling file merges for you. Still, what about cases where the conflict cannot be
resolved automatically?

Don't worry, gitdocs makes handling this simple. In the event of a conflict,
**all the different versions of a document are stored** in the repo tagged with the **git sha** for each
committed version. The members of the repo can then compare all versions and resolve the conflict.

## Planned Features

Gitdocs is a young project but we have big plans for it including:

 - Click-to-share instant access granting file access to users using a local tunnel or other means.
 - Indexing and full-text search for all documents in a repo
 - Better access to the versions for a particular file within the web front-end
 - Tagging and organizing of files within the web front-end

## Prior Projects

Gitdocs is a fresh project that we spiked on in a few days time. Our primary goals are to keep the code as simple as possible,
but provide the features that makes dropbox great. If you are interested in other Dropbox alternatives, be sure to checkout our notes below:

 * [SparkleShare](http://sparkleshare.org/) is an open source, self-hosted Dropbox alternative written using C# and the [Mono Project](http://www.mono-project.com/Main_Page).
   More mature but has a lot of dependencies, and lacks some of the features planned in Gitdocs.
 * [DVCS-Autosync](http://mayrhofer.eu.org/dvcs-autosync) is a project to create an open source replacement for Dropbox based on distributed version control systems.
   Very similar project but again we have features planned that are out of scope (local tunnel file sharing, complete web ui for browsing, uploading and editing).
 * [Lipsync](https://github.com/philcryer/lipsync) is another similar project. We haven't looked at this too closely, but thought we would mention it in this list.
 * [bitpocket](https://github.com/sickill/bitpocket) is a project that uses rsync to synchronize data. Interesting concept, but
   lacks revision history, author tracking, etc and we have features planned that are out of scope for this project

If any other open-source dropbox alternatives are available, we would love to hear about them so let us know!
