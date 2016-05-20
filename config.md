dotsys.cfg
==========

Nearly all of the dotsys defaults can be superseded with a repo level and topic level dotsys.cfg file.  
A dotsys.cfg file located in a topic directory tells dotsys how to treat a topic and a repo config file 
allows you to easily supersede topic settings.

TOPIC CONFIG (topic/dotsys.cfg)
-------------------------------
change repo to install from

    repo: user/repo_name
    
specify a manager ([none], app, cmd, topic )

    manager: cmd
    
test determines if installed on system by other means (default: is_cmd $topic)
				            
    installed_test: [shell test] 
    
manager package name if not (default: topic name)

    name: package_name
     				           
specific manager package name ex: brew: python,  pact: python2

    brew: package_name 
    	
topic dependencies	

    deps:
      - topic_name

symlinks (override $HOME directroy as destination)

    symlinks:
      - file.symlink->$HOME/subdir/_file


MANAGER CONFIG OPTIONS
----------------------
Install with apps manager ie: cask, chocolaty, yum
    
    manager: app 

Install with command line manager ie: brew, apt-get
			        
    manager: cmd 

Install with a specific manager

    manager: npm


PLATFORM CONFIG OPTIONS
-----------------------

full platform names (do not use in config files)

    linux-mac:
    windows-cygwin:
    
specific platform name (only linux-mac, windows-cygwin)

    mac:
    cygwin: 

generic platform name (all windows-*, all linux-*)

    windows:
    linux:

Include/exclude for platform (use 'x' to exclude and 'i' to include)
any platform not excluded generically or specifically will be installed
when a generic platform is excluded you must explicitly include any specific platforms you want to use

exclude all linux platforms

    linux: x
    
override include linux-mac

    mac: i                                        


TOPIC CONFIG: PLATFORM SPECIFIC (windoes/mac/linux/freebsd/mysys)
-----------------------------------------------------------------
All base config settings are applicable as platform children and will supersede the base config

    windows: i
      manager: app 
      repo: user/repo_name
      symlinks:
        - file.symlink->$HOME/subdir/_file 
    
    linux: x


TYPICAL TOPIC EXAMPLE (vim)
---------------------------

    manager: cmd
    brew: macvim
      installed_test: mvim
    windows:
      symlinks:
        - vimrc.symlink -> $HOME/_vimrc


REPO CONFIG (user/repo/dotsys.cfg)
----------------------------------

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


REPO CONFIG TOPIC OVERRIDES
---------------------------
all topic child settings apply

override topic1 repo and exclude on windows

    topic1:  					          
      repo: alternate/repo				  
      windows: x

Exclude topic2

    topic2: x  					          


INCLUDE / EXCLUDE RULES
-----------------------
Include all files

    package: i              
      file1:                # include
      file2: x              # include
      file3: i              # include

Exclude all files

    package: x              
      file1:                # exclude
      file2: x              # exclude
      file3: i              # exclude

Check each file individually

    package:                
      file1:                # include
      file2: x              # exclude
      file3: i              # include


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