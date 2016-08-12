Anotomy of a dotsys.cfg file
============================

Nearly all of the dotsys defaults can be superseded with a dotsys.cfg file at the repo level and or topic level.  
A dotsys.cfg file located in a topic directory tells dotsys how to treat a topic and a repo config file 
allows you to easily supersede topic settings.  

#### CFG FILE FORMATTING RULES

Cfg files use a simplified YAML format and must comply with the following rules:

- INDENTS MUST BE TWO SPACES!
- Settings are comprised of `key: value` pairs
- Some settings allow lists of items, prefixed with a dash '-'
- Indented settings only pertain to the parent setting.
- A key may not contain a dash '-' character, but values and topics can.
 
If you need to refer to a topic containing dashes such as  "apt-get" use the syntax:
    
    aptget: google-chrome
    
    
BUILT-IN TOPICS & VIM CFG EXAMPLE
---------------------------------

The configuration for vim happens to be a dotsys built-in topic, so your repo version of 'vim' would not require a cfg file,
just add your `vimrc.symlink` to the 'vim' directory and that's it!

This is what the Built-in vim/dotsys.cfg looks like

    manager: cmd
    brew: macvim
      installed_test: mvim
    windows:
      symlinks:
        - vimrc->$HOME/_vimrc
        
You will learn more about these settings below, but in summary what we did above was the following.

- Use the command line manger `cmd`
- When brew is the manger use the package `macvim` instaed of `vim`
- Brew must use the installed test `mvim` to determine if it is installed
- For the windows platform use an alternate symlink destination for the `vimrc` file


TOPIC CFG SETTINGS (Topic/dotsys.cfg)
-------------------------------------

#### TOPIC NAMES

First lets recall that a topic is merely a directory in your repo which contains related files.  How you name your topic 
directories is important.  Topics should always be named after the system command when possible!  The topic name is used as 
the default `package_name` and `installed_test`.  Both of these settings can be modified when necessary in the topic/dotsys.cfg file.


#### INSTALLED TESTS

The `installed_test` is very important.  Dotsys will check if the specified isntalled test exists on your system. This allows 
dotsys to respect existing versions on your system. For example: If you have a version of vim installed on your system, dotsys 
will test for the command `vim` and if found will not re-install it unless you explicitly use the --force option.  
If necessary you could override the installed test and package name for a topic using the following lines in a cfg file:

    installed_test: some POSIX comaptable command to exicute


#### PACKAGE NAMES

The `package_name` is used by a topic's designated manager to install the correct package. You can override the 
default package name for all managers with the following line :

    package_name: valid-package-name
    
    
In some cases the package name will vary from manager to manager.  You can address this by specifying a package name
for any manager that uses a package name that differs from the default:

    brew: node
    scoop: nodejs
    yum: nodejs npm
    
Notice yum has two package names! Since most nodejs packages include npm we do this to level the playing field. When 
dotsys installs the node topic with yum the executed command is `sudo yum install nodejs npm`, which is completely valid 
since all managers will accept multiple package names.

    
#### DEFAULT MANAGERS

If your topic name satisfies the requirements for `package_name` and `installed_test` then most topics will only need to specify a
default manager.  Most systems have a command line manager `manger: cmd` and an application manger `manager: app`.  Dotsys will
choose the apropriate default manger based on the detected platform.  See .dotsys/dotsys.cfg for defaults.

Some platform managers such as Yum, handle both cmd and app packages in which case either would work fine.  However, the goal of 
dotsys is to be cross platform so always be mindful of this and choose the appropriate manger.  The general rule is If the package is 
available on the command line it should use cmd, otherwise app. 

It's also worth noting that any topic can be a manager such as npm `manger: npm'.  

Install with command line manager ie: brew, apt-get
			        
    manager: cmd 
    
Install with apps manager ie: cask, chocolaty, yum
    
    manager: app 

Install with a specific manager (any topic with a manager.sh file)

    manager: npm
    
    
#### DEPENDENCIES

Some topics may require other topics.  This is easily accomplished with a cfg file.  For example gulp requires the following dependencies.
Always specify all dependencies as required, even though npm is typically included with node we still list it!

    deps:
      - node
      - npm
      
#### SYMLINKS

By default any file with a ".symlink" extention is linked to your $HOME directory and given a "." prefix.  In some cases
this destination location and or file name need to be customised

    symlinks:
      - src_name->$HOME/subdir/_dst_name

src_name: The repo source file name (no "." prefix or .symlink extension)
dst_name: The exact destination file name with prefix and extension
  


PLATFORM SETTINGS
-----------------

Full platform names contain a gneric-specific combination:

    linux-mac:
    linux-centos:
    windows-cygwin:
    windows-babun:
    
Generic platforms apply to all specific platforms sharing the generic prefix.

    windows:
    linux:
    
Specific platform names apply only to that one specific platform.

    mac:
    cygwin: 


Platforms may contain an include or exclude value (use 'x' to exclude and 'i' to include), this is
how dotsys knows which packages get installed on specific platforms.

Any platform not excluded generically or specifically will be included by default. When a generic 
platform is excluded you must then include any specific platforms you want to include.

Exclude all platforms except for mac:

    windows: x
    linux: x
    mac: i


#### PLATFORM SPECIFIC OVERIDES

All base config settings are applicable as platform children and will supersede the base config.
In the below example the settings will only apply to windows platforms.

    windows: i
      manager: app
      symlinks:
        - file->$HOME/subdir/_file 


REPO CFG SETTINGS (user/repo/dotsys.cfg)
----------------------------------------

default repo for all topics (branch is optional, defaults to master)

    repo: user_name/repo_name\[:branch\]	
    
platform manger overrides for windows(defaults shown)  
                      
    windows:
      app_manager: choco
      cmd_manager: pact

platform manger overrides for mac (defaults shown)

    mac:
      app_manager: cask
      cmd_manager: brew


#### REPO CONFIG TOPIC OVERRIDES

all topic child settings apply

override topic1 repo and exclude on windows

    topic1:  					          
      repo: alternate/repo				  
      windows: x

Exclude topic2

    topic2: x 
    
     					          
INCLUDE / EXCLUDE RULES
-----------------------

As we discussed you can include / exclude a topic for a platform.  
You can also include / exclude files and directories from topics.
                                        
Include all files for a topic

    topic: i              
      file1:                # include
      file2: x              # include
      file3: i              # include

Exclude all files for a topic

    topic: x              
      file1:                # exclude
      file2: x              # exclude
      file3: i              # exclude

Check each file individually

    topic:                
      file1:                # include
      file2: x              # exclude
      file3: i              # include
      
exclude a file for a platform in a topic cfg

    platform:
      file1: x
      file2: i
        
exclude a directory for a platform in a repo cfg

    
    topic:
      platform:
        dir1:
          file1: x
          file2: i
        dir2:x


TOPIC TASKS (alternate to topic.sh functions or task.sh scripts)
----------------------------------------------------------------
(not implemented?)

install: install command
uninstall: uninstall command
update: update command	
upgrade: update command
freeze: update command


SPECIAL FILE EXTENSIONS & DIRECTORIES
-------------------------------------
A file to be symlinked

    *.symlink
		
Source file from when any shell loaded

    *.shell 

Source file when topic loaded

    *.$topic

Files in directory are symlinked to user/bin

    topic/bin


TODO: SETTINGS (*.settings)
---------------------------

ex: finder.settings file defines individual functions for each setting

    show_hiden_files (){
      commands to execute
    }
    
ex: dock.settings file defines individual functions for each setting

    auto_hide (){
      commands to execute
    }

Now each setting can be controlled by cfg file

    settings_windows: i	          
    settings_osx:
      dock: i			          
        auto_hide: x
      finder:
        show_hidden_files: i
        as_list: x
    settings_windows:
    settings_freebsd:
    settings_linux: