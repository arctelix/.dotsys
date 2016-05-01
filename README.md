# DOTSYS

### A platform agnostic package-manager with dotfile integration!

This system is based on the topic-centric concept introduced by Zach Holman.  If 
you are using this system and are familiar with package mangers like brew..

### Yoy already know how to use it!

NOTE: A repo is any github repository containing topic-centric dotfiles

Bootstrap a new machine from a remote repo:
> dotsys install github_user_/repo_name

Try a somebody else's vim config:
> dotsys install vim from other_user/repo_name

Install a new topic on your system:
> dotsys install tmux

Install a new OS app (no topic required):
> dotsys install app google-chrome

Install a new command line utility (no topic required):
> dotsys install cmd zip

Install a node package (no topic required):
> dotsys install node package gulp

Update all local data (update package lists, reload bash config, etc):
> dotsys update

Update just package managers:
> dotsys update managers

Update only brew:
> dotsys update brew

Upgrade everything on your system:
> dotsys upgrade

Upgrade a software packages:
> dotsys upgrade vim

Upgrade your repo (auto push or pull remote repo)
> dotsys upgrade repo

Remove a topic's software package and system changes (topic files remain intact):
> dotsys uninstall vim

Remove all packages and changes installed with dotsys:
> dotsys uninstall

Remove all changes from a repo you tried:
> dotsys uninstall other_user/repo_name


### Why another dotfile management system ?

Most people have developed dotfile systems that integrate system configuration and bootstrapping 
which makes it difficult to simply share dotfiles.  This also inevitably limits the ability to 
really share dotfiles.  Dotsys separates these two concepts so dotfies can be shared with everyone.

### Why another package manger ?

Dotsys is not really a package manager at all.  We simply chooses the correct package manager
for any given topic on a given platform.  By allowing any topic to be a manger and allow any topic
to be managed the system is limitless. Secondly, there are no existing package managers 
out there that support customisation of packages (dotfiles) and dotsys does!

Say you run the command:
> dotsys install gulp

Depending on your system dotsys will do the following:
- Ubuntu   : install Node.js with **apt-get** and install **gulp** with **npm**
- Debian   : install Node.js with **apt-get** and install **gulp** with **npm**
- BSD      : install Node.js with **pkg** and install **gulp** with **npm**
- Mac      : install Node.js with **brew** and install **gulp** with **npm**
- Windows  : install Node.js with **Scoop** and install **gulp** with **npm**
- Linux    : install node.js with **yum** and install **gulp** with **npm**
- Babun    : install Node.js with **pact** and install **gulp** with **npm**
- Mysys    : install Node.js with **mingw-get** and install **gulp** with **npm**

In case you were wondering.. 
> dotsys install google-chrome

Yes, dotsys will install cask and install chrome with cask on a mac, chocolaty on windows, etc..


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

1) Place the extracted repo ".dotsys" in the directory you want to install it (your dotfiles directory is a great choice)
2) From your shell of choice run the install script:
> path/to/.dotsys/install.sh

Then just follow the prompts in your termnal.

### Windows without bash integration
If you want to use Babun use command prompt to execute:
> path/to/.dotsys/install.bat

Otherwise install your posix shell of choice (Cygwin, Mysys, etc.) and follow the instructions for Not Windows.







