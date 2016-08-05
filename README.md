DOTSYS
======

A platform agnostic package-manager with dotfile integration!
-------------------------------------------------------------

This system is based on the topic-centric concept introduced by Zach Holman.  If 
you are using this system and are familiar with package mangers like brew..

You already know how to use it!
-------------------------------

#### BASIC ACTIONS

Dotsys actions are install, uninstall, update, upgrade, & freeze.  These actions
can be applied to all topics, a single topic, or a list of topics.  

Perform action on all topics:
> dotsys \<action\>

> `dotsys install`

Perform an action on specific topics
> dotsys \<action\> \<topics\>

> `dotsys upgrade tmux vim`

Perform an action on topics from another repo
> dotsys \<action\> \<topic\> from \<repo\>

> `dotsys uninstall vim from user/repo`

#### LIMIT ACTIONS

You can also limit an action to a specific part of dotsys.

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

A repo is simply a github repository containing a directory for each topic you wish to maintain. When
you make changes to your repo, it will be synced to github so you can roll those changes out on all
the systems you maintain.

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

This way your repo is updated automatically and the next time you run 
`dotsys install`, you get the exact same setup you had previously used!


Why another package manger ?
----------------------------

Dotsys is not really a package manager at all, more like a package manager wrapper.  We simply choose
the correct package manager for any given topic on a given platform.  By allowing any topic to be a 
manger and allowing any topic to be managed the system is limitless. Secondly, there are no existing package 
managers out there that support custom setting file management (dotfiles) and dotsys does!  The best way to 
illustrate this is by example of the process.

Say you have a topic for gulp and run the command:
> `dotsys install gulp`

1. Dotsys will check if node is installed and if not :

    - Ubuntu   : install Node.js with **apt-get** 
    - Debian   : install Node.js with **apt-get** 
    - BSD      : install Node.js with **pkg**
    - ArchLinux: install Node.js with **pacman** 
    - Mac      : install Node.js with **brew**
    - cygwin   : install Node.js with **scoop**
    - Linux    : install node.js with **yum**
    - Msys     : install Node.js with **mingw-get**

3. Then, since we know that npm is required for gulp, install **npm** if it's not already installed.

4. Start the **gulp** install process by installing it with **npm**.

5. Check for a custom install function in **gulp/topic.sh** and run it (make any custom modifications here).

6. Check for any **.gulp** files in other topics and source them as required.

7. Check for custom dotfiles and symlink them to the proper location, such as **npmrc.symlink**.

8. Any file in the gulp topic directory with a **.shell** extension will be sourced by your shell of choice at startup. 
You can add some functions for standard project configs in a **functions.shell** file. For example gulp-init-django and gulp_init_rails.

Why is dotsys better than a package manager ?
---------------------------------------------

Quite simply, dotsys manages your customized packages.  When you install vim with dotsys, you get YOUR fully customized 
version of vim not the generic version!  The best part is you don't need to worry about repackaging and maintaining 
vim, just make changes to your vimrc.symlink and dotsys will handle everything else.  Dotsys builtin topics like vim, will
take care of essential mods. For example on windows the '.vimrc' file needs to be called '_vimrc'.

Again we'll illustrate this by example :

1. You decide to make some changes to your `.vimrc` at work and test it out by running `dotsys update vim`.
    - Dotsys will commit the change to your local repo, re-source any required files, and update symlinks

2. If you like the changes and want to push it to your remote repo, run `dotsys upgrade repo`
    - Dotsys will push the changes to your remote repo

3. When you get home you can run `dotsys upgrade repo` & `dotsys update vim`.
    - Dotsys will pull the changes from your remote repo and update your local vim with your changes.

That's cool, what else does it do ?
-----------------------------------

- Supports all Linux variations including Mac & Windows 10 w/Bash, Windows Babun, Windows Cygwin, Windows Mysys
- Supports all posix compliant shells and has NO DEPENDENCIES.
- Allows a configuration to be deployed on multiple platforms.
- Decouples software installation and system config from dotfiles.
- Separates sourcing of topic extensions from dotfiles.
- Automates repository download, installation, and management.
- Facilitates clear hierarchy of global shell config files.
- Supports multiple repositories and branches.
- Install topics from multiple repositories simultaneously.
- Maintain unlimited configurations for one repository.
- Manages personal information and separates from public repo.
- Minimal and intelligent defaults that are easily superseded.
- Allows user to choose exactly what they want form a config!
- Easily review and modify repo configuration before installation.
- Constant visual feedback on what's happening.
- Provides dependency management system for topics.
- Guided setup and install (no docs or code to read).
- Optionally migrate existing dotfiles and or topics to dotsys.
- Automatically backs up any original files (safety first!).
- Management and organization of OS settings and versions (soon).
- Stub file template variables to automate collection of user data.
- Topics are easy to create, share, and sync between machines.
- Detailed logging of all actions
- An API you already know how to use.
- AND MANY MORE FEATURES

More details to come, stay tuned...

![Dotsys install screen shot](https://github.com/arctelix/.dotsys/blob/master/screen%20shot%20install.png?raw=true "Dotsys install screen shot")


WARNING!
--------

THIS IS A WORK IN PROGRESS!
The infrastructure for all platforms exists, but have not all been fully 
tested and will likely have minor issues that need tweaking.

TESTED PLATFORMS:
- linux-mac (El Capitan)
- linux-ubuntu (16.04)
- windows-babun (windows8/windows10)
- windows-cygwin (windows8/windows10)

If you are interested in helping out that would be awesome!

The most pressing open items are as follows:
 - any topic you think is important enough to have builtin
 - manager.sh files for : pkg & mingw-get
 - see main.sh for the todo list & road map items
 
Builtin topic criteria:
 - Must be a commonly installed topic
 - Must do something to benefit all users 
 - Must be compatible with all versions
 
Please submit your pull requests & issues!

Installation
============

1) First download and extract the dotsys repository from GitHub to a location 
of your choosing (your home directory or .dotfiles directory are good choices).

NOTE: The dotsys root directory must be named ".dotsys" witht the "."

Or download & extract with curl & zip:

    curl -Lk https://github.com/arctelix/.dotsys/archive/master.zip -o .dotsys.zip
    unzip .dotsys.zip
    mv .dotsys-master .dotsys
    rm .dotsys.zip
    
Or download & extract with curl & tar:

    curl -Lk https://github.com/arctelix/.dotsys/archive/master.tar.gz -o .dotsys.tar.gz
    tar -xvzf .dotsys.tar.gz
    mv .dotsys-master .dotsys
    rm .dotsys.zip  

## All platforms (except windows without native bash)

2) From your posix compatible shell of choice run the install script:

    path/to/.dotsys/installer.sh

3) Follow the prompts in your terminal.

## Windows without native bash

OPTION 1: To use babun as your base system

2) Run the following script from the command prompt (notice the .bat extension):
 
`path/to/.dotsys/installer.bat`

OPTION 2:

2) Install your posix shell of choice (Cygwin, Mysys, etc.)

OPTIONS 1&2: 

3) Now follow the steps for All Platforms


Getting Started with dotfiles and dotsys
----------------------------------------
If you have never managed your dotfiles before Dotsys makes it easy!
If you already have a dotfile management system it's easy to migrate!

1) Create a GitHub account if you do not have one already

2) Install dotsys as per the instructions above
    
3) When prompted, enter a new repo or an existing repo in the format:

    github_user_name/repo_name
    
4) Dotsys will ask if you want to search for existing topics and dotfiles on 
your system and add them to the dotsys repo automagically!

From now on, when you make changes to your system, use dotsys and you
will never have to do it again!


What the hell is a topic?
-------------------------

A topic is how dotsys organizes your custom settings. If you currently use vim and had 
dotsys search for exiting dotfiles this is probably done already, but we'll walk through
the process so you can create topics that are not part of dotsys already.

First create a directory in your local repo manually or with the following command:

    # HINT: Topic names should corispond to it's shell command when possible!
    mkdir ~/.dotfiles/<github_user_name>/<repo_name>/vim

Add any required dotfiles, but remove the "." prefix and add a ".symlink" extension:

    touch ~/.dotfiles/<github_user_name>/<repo_name>/vim/vimrc.symlink

Add some aliases for the shell:

    touch ~/.dotfiles/<github_user_name>/<repo_name>/vim/aliases.shell
    
Optionally create a dotsys.cfg file in the topic directory
See Anatomy of a dotsys.cfg file for dotsys.cfg options:

    # Cfg files use a basic yaml format using TWO spcaes for indents
    touch ~/.dotfiles/<github_user_name>/<repo_name>/vim/dotsys.cfg
    
NOTE: In order for git to save a directory it must contain at least one file.  A great
way to insure that a topic directory is preserved in your remote repo is to add a 
blank dotsys.cfg file.


System file names and extensions
--------------------------------

### topic/\*.symlink

Files or directories with a ".symlink" extension will be linked to the home directory and given a "." prefix
unless a custom path/name is specified in the dotsys.cfg


### topic/topic.sh
    
This file defines functions for any required dotsys actions.

### topic/manager.sh

This file designates a topic as a manager and defines functions for any required dotsys manager actions.

### topic/packages.yaml

A manager topic can have a packages.yaml file which is a list of packages that do not required topics but
you want to install. Each package is entered with a colin "package_name:",  you will see why when you learn about cfg files.

### topic/bin/*

Any files in a topic's bin directory will be available in your shell environment, bash, zsh, etc...

### topic/.*

Any file prfixed with a "." will be ignored, but remains part of the repo.


Stub files
----------

A stub file provides any required boilerplate and allows us to source your custom settings from the corresponding .symlink, 
source .topic files from other topics, and collect required user and system data for the topic.

### \*.stub
    
This is the template file confining the boiler plate code and *stub template variables* (all caps in curly braces).  
All topic specific variables get prefixed with `TOPIC`.

For example the built in gitconfig.stub includes:

    name = {TOPIC_GLOBAL_AUTHOR_NAME}
    email = {TOPIC_GLOBAL_AUTHOR_EMAIL}
    helper = {CREDENTIAL_HELPER}

When dotsys sees the variable names and the data is not already stored it will prompt the user:
    
    What is your git global author name?
    What is your git global author email?
    
Some basic default values are builtin, such as:

    TOPIC_USER_NAME
    TOPIC_USER_EMAIL
    
### \*.vars

Provides values for stub template variables as required. Functions are lower case versions of
their corresponding stub template variable. See .dotsys/builtins/git/gitconfig.vars for more.

    global_author_name () {
        echo "$(whoami)"
        return 1
    }
    
Return 1 when user confirmation of the default value is required. 
Return 0 for system data that doe not require user confirmation.

### \*.sources

Enables sourcing of files from other topics by providing a `format_source_file` function.
The function must return the required lines to source a file in the target topics language.
The returned sting will be written to the target stub file.

For example vim's vimrc.sources file looks like this:

    format_source_file() {
        local source_file="$1"
        echo "execute 'source $source_file'"
    }
   
### .<topic>    

Any topic in dotsys with a .stub file and a .sources file can source files from other topics.
Simply add the topic name as a file extension and it will get sourced by that topic on load.
For example `some_file.vim` will be sourced by vim on load.

##### The following are built in to dotsys:
|file extention|purpose                                                             |
|:-------------|:-------------------------------------------------------------------|
|\*.shell      | Sourced every time your shell of choice is loaded                  |
|\*.bash       | Sourced every time bash is loaded                                  |
|\*.zsh        | Sourced every time zsh is loaded                                   |
|\*.vim        | Sourced every time vim is loaded                                   |
|\*.tmux        | Sourced every time tmux is loaded                                 |
|\*.git        | Sourced every time git is loaded                                   |

##### Loading order
|file name     | loading order                                                      |
|:-------------|:-------------------------------------------------------------------|
|path.\*       | Sourced first for a given topic extension                          |
|funcitons.\*  | Sourced second for a given topic extension                         |
|aliases.\*    | Sourced third for a given topic extension                          |
|completion.\* | Sourced fourth for a given topic extension                         |
|\*.\*         | All other files names are sourced in alphabetical order            |


#### DEPRECIATED FILES (for compatibility with exiting dotfile managers)

    A topic.sh file replaces the folloing files:
    install.sh, uninstall.sh, update.sh, upgrade.sh, freeze.sh 
    
    The *.shell extenion replaces the *.sh extenion as to not interfere
    imported systems that do not utilize stub files. 
     
    .exclude-platforms is replaced by dotsys.cfg files.


Anatomy of a dotsys.cfg file
----------------------------

https://github.com/arctelix/.dotsys/blob/master/config.md

Shell System
------------
https://github.com/arctelix/.dotsys/blob/master/shell.md


How do I learn more about dotsys and it's features ?
----------------------------------------------------

Just ask dotsys for help.
> `dotsys --help`







