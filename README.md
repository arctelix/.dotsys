DOTSYS
======

A platform agnostic package-manager with dotfile integration!
-------------------------------------------------------------

This system is based on the topic-centric concept introduced by Zach Holman.  If 
you are using this system and are familiar with package mangers like brew..

You already know how to use it!
-------------------------------

A repo is any github repository containing topic-centric dotfiles.
Dotsys actions are install, uninstall, update, upgrade, & freeze

#### BASIC ACTIONS

Perform action on all topics:
> dotsys \<action\>

> `dotsys install`

Perform an action on specific topics
> dotsys \<action\> \<topics\>

> `dotsys install tmux vim`

Perform an action on topics from another repo
> dotsys \<action\> \<topic\> from \<repo\>

> `dotsys install vim from user/repo`

#### LIMIT ACTIONS

> dotsys \<action\> \<limit\>

Just symlinks:
> `dotsys update links`

Just scripts:
> `dotsys update scripts`

Just package managers:
> `dotsys update managers`

Just packages:
> `dotsys upgrade packages`

Just dotsys (core system):
> `dotsys upgrade dotsys`

#### REPO MANAGEMENT (local and remote)

Your default repo's "master" branch
> dotsys \<action\> repo

> `dotsys upgrade repo`
           
Your default repo's "min" branch
> dotsys \<action\> repo min    

> `dotsys install repo min`

Another repo's master branch
> dotsys \<action\> user/repo  
    
> `dotsys uninstall user/repo`  

Another repo's "min" branch
> dotsys \<action\> user/repo:min  

> `dotsys update user/repo:min`


Why another dotfile management system ?
---------------------------------------

Most people have developed dotfile systems that integrate system settings and software instalation 
which makes it difficult to simply share dotfiles.  This also inevitably limits the ability to 
really share and fork dotfiles.  Dotsys separates these functions so dotfies can be easily managed 
,shared shared with everyone, and forked in a more usefull way.

Why do i need dotsys if i don't manage my dotfiles as topics ?
--------------------------------------------------------------

Because we have some brains built in, right out of the box you can do things like..

Install a new OS app (no topic required):
> `dotsys install app google-chrome`

Install a new command line utility (no topic required):
> `dotsys install cmd zip`

Install a node package (no topic required):
> `dotsys install node packages gulp`


Why another package manger ?
----------------------------

Dotsys is not really a package manager at all, more like a package_manager wrapper.  We simply chooses 
the correct package manager for any given topic on a given platform.  By allowing any topic to be a 
manger and allow any topic to be managed the system is limitless. Secondly, there are no existing package 
managers  out there that support custom setting management (dotfiles) and dotsys does!  The best way to 
illustrate this is by example.

Say you run the command:
> `dotsys install gulp`

Dotsys will check for node and if not installed will:
- Ubuntu   : install Node.js with **apt-get** 
- Debian   : install Node.js with **apt-get** 
- BSD      : install Node.js with **pkg**
- ArchLinux: install Node.js with **pacman** 
- Mac      : install Node.js with **brew**
- Windows  : install Node.js with **Scoop**
- Linux    : install node.js with **yum**
- Babun    : install Node.js with **pact**
- Mysys    : install Node.js with **mingw-get**

After it's installed, your node topic's custom install function wil be run. Finally dotsys wil check 
for any symlinks you have in your topic, such as an npmrc.symlink and symlink it to the right place.

Then dotsys will will install **gulp** with **npm** and repeat process for your npm topic.

That's cool, what else does it do ?
-----------------------------------

- Supports Mac, all Linux variations, FreeBSD, OpenBSD, Ubunto, Debian, Windows 10 w/Bash, Windows Babun, Windows Cygwin, Windows Mysys
- Supports all posix compliant shells and has NO DEPENDENCIES.
- Allows a configuration to be deployed on multiple platforms.
- Decouples software installation and system config from dotfiles.
- Automates repository download, installation, and management.
- Supports multiple repositories and branches.
- Save unlimited configurations for one repository.
- Manages personal information and separates from public repo. 
- Minimal and intelligent defaults that are easily superseded.
- Allows user to choose exactly what they want form a config!
- Easily review and modify yaml configs before installation.
- Constant visual feedback on what's happening.
- Provides dependency management system for topics.
- Guided setup and install (no docs or code to read).
- Optionally migrate existing dotfiles and or topics to dotsys.
- Automatically backs up any original files (safety first!).
- Separates dotfiles configs from extension sourcing.
- Management and organization of OS settings and versions (soon).
- An API you already know how to use.
- AND MANY MORE FEATURES

more details to come, stay tuned...

WARNING!
--------

THIS IS A WORK IN PROGRESS AND ONLY SUFFICIENTLY TESTED ON OSX WITH BASH!
The infrastructure for all platforms exists, but has not been tested
and will likely have platform specific issues that need to be tweaked.

If you are interested in helping out that would be awesome!
Please submit your pull requests!

Installation
============

1) First download and extract the dotsys repository to a location 
of your choosing (your home directory or .dotfiles directory are good choices).

NOTE: The dotsys root directory must be named ".dotsys" witht he "."

## All platforms (except pre windows 10 w/Bash)

2) From your posix compatible shell of choice run the install script:

`path/to/.dotsys/installer.sh`

3) Follow the prompts in your terminal.

## Windows without native bash integration

OPTION 1: To use babun as your base system

2) Run the following script from the command prompt (notice the .bat extension):
 
`path/to/.dotsys/installer.bat`

OPTION 2:

2) Install your posix shell of choice (Cygwin, Mysys, etc.)

OPTION 1&2: 

3) Now follow the steps for All Platforms

How do I learn more about dotsys and it's features ?
----------------------------------------------------

Just ask dotsys for help.
> `dotsys --help`







