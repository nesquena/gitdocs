# Gitdocs

Collaborate on files and docs through a shared git repository. gitdocs will automatically push changes to the repo as well as pull in changes.
This allows any git repo to be used as a collaborative task list or wiki for a team.

You can also start a web front-end allowing the repo to be viewed through the browser.

## Installation

Install the gem:

```
gem install gitdocs
```

If you have Growl installed, you'll probably want to run `brew install growlnotify` to enable Growl support.

## Usage

First add the doc folders to watch:

```
gitdocs add my/path/to/watch
```

You can remove and clear paths as well:

```
gitdocs rm my/path/to/watch
# or gitdocs clear
```

You need to startup gitdocs:

```
gitdocs start
```

You can also `stop` and `restart` gitdocs as needed. Run

```
gitdocs status
```

for a helpful listing of the current state. Once gitdocs is started, simply start editing or adding files to your
designated git repository. Changes will be automatically pushed and pulled to your local repo.

You can also have gitdocs fetch a remote repository with:

```
gitdocs create my/path/for/doc git@github.com:user/some_docs.git
```

This will clone the repo and add the path to your watched docs. Be sure to restart gitdocs
to have path changes update:

```
gitdocs restart
```

To view the docs in your browser with file formatting:

```
gitdocs serve
```

and then visit `http://localhost:8888` for access to all your docs in the browser.

## Known Issues

- Currently, gitdocs only works on Mac OS X because we rely on fsevent. We plan to make this platform independent soon.
- We don't handle conflicts, but we will alert you that a conflict has occurred
