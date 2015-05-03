# Gitdocs

[![Gem Version](https://badge.fury.io/rb/gitdocs.png)](http://badge.fury.io/rb/gitdocs)
[![Code Climate](https://codeclimate.com/github/bazaarlabs/gitdocs.png)](https://codeclimate.com/github/bazaarlabs/gitdocs)
[![Build Status](https://travis-ci.org/nesquena/gitdocs.svg?branch=master)](https://travis-ci.org/nesquena/gitdocs)
[![Inline docs](http://inch-ci.org/github/nesquena/gitdocs.png?branch=master)](http://inch-ci.org/github/nesquena/gitdocs)
[![Dependency Status](https://gemnasium.com/nesquena/gitdocs.svg)](https://gemnasium.com/nesquena/gitdocs)
[![Coverage Status](https://coveralls.io/repos/nesquena/gitdocs/badge.png?branch=master)](https://coveralls.io/r/nesquena/gitdocs)

Open-source dropbox alternative powered by git. Collaborate on files and tasks without any extra hassle.
gitdocs will automatically keep everyone's repos in sync by pushing and pulling changes.
This allows any git repo to be used as a collaborative task list, file share, or wiki for a team.
Supports a web front-end allowing each repo to be accessed through your browser.

**Note:** Gitdocs has been tested on multiple unix systems including Mac OS X and Ubuntu.
Windows support is [half-baked](https://github.com/nesquena/gitdocs/issues/7)
but we plan to tackle that shortly in an upcoming release.

## Why?

Why use gitdocs for your file and doc sharing needs?

 * **Open** - gitdocs is entirely open-source under the MIT license
 * **Simple** - gitdocs is the simplest thing that works in both setup and usage
 * **Secure** - gitdocs leverages git (and existing providers like github) to store your data safely.
 * **Versatile** - share task lists, code snippets, images, files or just use it as a wiki (with our web front-end).
 * **Portable** - access your files on any client that can use git.

The best part is that getting started using this project is quick and simple.

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

Requires ruby1.9+ and rubygems. Install as a gem:

```
gem install gitdocs
```

If you have Growl installed on Max OSX, you'll probably want to run:

```
brew install caskroom/cask/brew-cask
brew install growlnotify
```

to enable Growl notification support.

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
 * View revision history for every file in your share
 * Revert a file to any previous state in the file's history
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

## Gitdocs in Practice

At Miso, our team actually uses gitdocs in conjunction with Dropbox. We find Dropbox is ideal for galleries, videos,
and large binary files of all sorts. We use gitdocs for storing our actual "docs":
Task lists, wiki pages, planning docs, collaborative designs, notes, guides, code snippets, etc.

You will find that the gitdocs browser front-end is well suited for this usage scenario
since you can browse formatted wiki pages, view files with smart syntax highlighting,
edit files with a rich text editor, search all your files, as well as view individual file revision histories.

## Planned Features

Gitdocs is a young project but we have many plans for it including:

 - Better handling of large binary files circumventing known git limitations
 - Click-to-share instant access granting file access to users using a local tunnel or other means.
 - Tagging and organizing of files within the web front-end
 - Better access to the versions for a particular file within the web front-end

## Contributors

Gitdocs is now primarily being developed by [Andrew Sullivan Cant](https://github.com/acant). Gitdocs was created at [Miso](http://engineering.gomiso.com) by [Joshua Hull](https://github.com/joshbuddy) and [Nathan Esquenazi](https://github.com/nesquena). 

We also have had several contributors:

  * [Chris Kempson](https://github.com/ChrisKempson) - Encoding issues
  * [Evan Tatarka](https://github.com/evant) - Front-end style fixes
  * [Kale Worsley](https://github.com/kaleworsley) - Custom commit msgs, revert revisions, front-end cleanup
  * [Andrew Sullivan Cant](https://github.com/acant) - Major improvements, grit support, core contributor

Gitdocs is still a young project with a lot of opportunity for contributions. Patches welcome!

## Prior Projects

Gitdocs is a fresh project that we originally spiked on in a few days time. Our primary goals are to keep the code as simple as possible,
but provide the features that makes Dropbox great. If you are interested in other Dropbox alternatives, be sure to checkout our notes below:

* [SparkleShare](http://sparkleshare.org/) is an open source, self-hosted Dropbox alternative written using C# and the [Mono Project](http://www.mono-project.com/Main_Page).
   More mature but has a lot of dependencies, and lacks some of the features planned in Gitdocs.
* [DVCS-Autosync](http://mayrhofer.eu.org/dvcs-autosync) is a project to create an open source replacement for Dropbox based on distributed version control systems.
   Very similar project but again we have features planned that are out of scope (local tunnel file sharing, complete web ui for browsing, uploading and editing).
* [Lipsync](https://github.com/philcryer/lipsync) is another similar project. We haven't looked at this too closely, but thought we would mention it in this list.
* [bitpocket](https://github.com/sickill/bitpocket) is a project that uses rsync to synchronize data. Interesting concept, but
   lacks revision history, author tracking, etc and we have features planned that are out of scope for this project
* [RubyDrop](https://github.com/meltingice/RubyDrop) git backed DropBox clone
* [git-sync](http://tychoish.com/essay/git-sync/) manual git syncing tool,
  which also use XMPP notifications
* [git-annex-assistant](http://git-annex.branchable.com/design/assistant/)
  directory sync tool based on [git-annex](http://git-annex.branchable.com/). (written in Haskell)
* [BitTorrent Sync](http://www.bittorrent.com/sync) BitTorrent based syncing
  tool, not open source or publicly defined protocol
* [StrongSync](https://secure.expandrive.com/strongsync) Dropbox clone utility,
  proprietary

If any other open-source dropbox alternatives are available, we would love to hear about them so let us know!
