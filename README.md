# DOTSYS

### A platform agnostic package-manager with dotfile integration!

This system is based on the topic-centric concept introduced by Zach Holman.  If 
you are using this system and are familiar with package mangers like brew..

### You already know how to use it!

NOTE: A repo is any github repository containing topic-centric dotfiles

Bootstrap a new machine from a remote repo:
> dotsys install from github_user_/repo_name

Install a new topic on your system:
> dotsys install tmux

Try a somebody else's vim config:
> dotsys install vim from other_user/repo_name

Update all local data (update package lists, reload bash config, etc):
> dotsys update

Update just package managers:
> dotsys update managers

Update brew:
> dotsys update brew

Update your local repo (pull changes from remote):
> dotsys update repo

Upgrade everything on your system (that nuts!):
> dotsys upgrade

Upgrade a just few topic packages:
> dotsys upgrade vim tmux node

Upgrade a repo (auto push or pull remote repo)
> dotsys upgrade repo           # your default repo's master branch

> dotsys upgrade repo min       # your default repo min branch

> dotsys upgrade user/repo      # another repo's master branch

> dotsys upgrade user/repo:min  # another repo's full branch

Remove a topic's software package and all system changes (topic files remain intact):
> dotsys uninstall vim

Remove all packages and changes installed with dotsys:
> dotsys uninstall

Remove all changes from a repo you tried and hated:
> dotsys uninstall from other_user/repo_name


### Why another dotfile management system ?

Most people have developed dotfile systems that integrate system settings and software instalation 
which makes it difficult to simply share dotfiles.  This also inevitably limits the ability to 
really share and fork dotfiles.  Dotsys separates these functions so dotfies can be easily managed 
,shared shared with everyone, and forked in a more usefull way.

### Why do i need dotsys if i don't manage my dotfiles as topics ?

Because we have some brains built in, right out of the box you can do things like..

Install a new OS app (no topic required):
> dotsys install app google-chrome

Install a new command line utility (no topic required):
> dotsys install cmd zip

Install a node package (no topic required):
> dotsys install node packages gulp


### Why another package manger ?

Dotsys is not really a package manager at all, more like a package_manager wrapper.  We simply chooses 
the correct package manager for any given topic on a given platform.  By allowing any topic to be a 
manger and allow any topic to be managed the system is limitless. Secondly, there are no existing package 
managers  out there that support custom setting management (dotfiles) and dotsys does!  The best way to 
illustrate this is by example.

Say you run the command:
> dotsys install gulp

Dotsys will check for node and if not installed will:
- Ubuntu   : install Node.js with **apt-get** 
- Debian   : install Node.js with **apt-get** 
- BSD      : install Node.js with **pkg** 
- Mac      : install Node.js with **brew**
- Windows  : install Node.js with **Scoop**
- Linux    : install node.js with **yum**
- Babun    : install Node.js with **pact**
- Mysys    : install Node.js with **mingw-get**

After it's installed, your node topic's custom install function wil be run. Finally dotsys wil check 
for any symlinks you have in your topic, such as an npmrc.symlink and symlink it to the right place.

Then dotsys will will install **gulp** with **npm** and repeat process for your npm topic.

In case you were wondering if this would work.. 
> dotsys install google-chrome

Yes, dotsys will install cask and then install chrome with cask on a mac, chocolaty on windows, etc..


### That's cool, what else does it do ?

- Supports Mac, Enterprise Linux, Fedora, FreeBSD, OpenBSD, Ubunto, Debian, Windows 10 w/Bash, Windows Babun, Windows Cygwin, Windows Mysys
- Supports all posix compliant shells and has NO DEPENDENCIES.
- Decouples package-managers and dotfiles form the configuration.
- Minimal and intelligent defaults that are easily superseded. 
- Dependency management system for topics.
- Allows a configuration to be deployed on multiple platforms.
- Automates repository download, installation, and management.
- Supports multiple repositories and branches.
- Easily review and modify what you want before install.
- Constant visual feedback on what's happening.
- On screen confirmation for all tasks or ride hands free!
- Guided configuration (no docs or code to read).
- Optionally migrate existing dotfiles and or topics to dotsys.
- Automatically backs up any original files we replace (safety first!).
- Management and organization of OS settings and versions (soon).
- An API you already know how to use.
- AND MANY MORE FEATURES

more details to come, stay tuned...

### WARNING!

THIS IS A WORK IN PROGRESS AND IS NOT SUFFICIENTLY TESTED!
The api could change and things could break at any time.

If you are interested in helping out that would be awesome!


## Installation 

### All platforms (except pre windows 10 w/Bash)

1. Place the extracted directory ".dotsys" where want to install it (your home directory is cool)
2. From your posix shell of choice run the install script:
> path/to/.dotsys/install.sh

Then just follow the prompts in your terminal.

### Windows without native bash integration

For a babun setup (noce the .bat extention):
> path/to/.dotsys/install.bat

Alternatively, install your posix shell of choice (Cygwin, Mysys, etc.) and run: 
> path/to/.dotsys/install.sh

Then just follow the prompts in your terminal.

### How do I learn more about dotsys and it's features ?

Just ask dotsys for help.
> dotsys --help







