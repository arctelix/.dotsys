dotsys.cfg
==========

Nearly all of the dotsys defaults can be superseded with a repo level and topic level dotsys.cfg file.  
A dotsys.cfg file located in a topic directory tells dotsys how to treat a topic and a repo config file 
allows you to easily supersede topic settings.

Topics should be named after the system command when possible, as dotsys will 
test for the topic name as an existing commend. For example:

> To crate a topic named for vim, you would crate a directory called 'vim', dotsys will test for the command 'vim' and if 
> it already exits will skip the package installation.  

This is actually very important.  It allows dotsys to respect previously installed versions of packages on your system.  
If you have a version of vim on your current system we will not overwrite it unless you explicitly use the --force
option.
    
However, on the mac platform you likely want to install 'macvim'.  Don't create another topic called 'macvim' 
just modify the dotsys.cfg for the 'vim' topic telling dotsys to use 'macvim' for brew.

    manager: cmd
    brew: macvim
      installed_test: mvim
    windows:
      symlinks:
        - vimrc.symlink->$HOME/_vimrc
        
The configuration for vim happens to be built in to dotsys, so all you need to do is create a folder called 'vim' and 
add your `vimrc.symlink` file and your done!  

Now if for some reason you wanted to override and use 'vim' on the mac platform instaed of 'macvim'.  Create add the 
following to your 'vim' topic's dotsys.cfg.

    brew: vim
      installed_test: vim

You will also notice we changed the symlink location for windows platforms to '$HOME/_vimrc_' rather then '$HOME/.vimrc'.  
The details for all config file settings are explained below, so that you can implement topics that are not built in to dotsys.  
Please submit pull requests for your topic configs!  Look at `.dotsys/builtins` for more examples of how to configure a topic.



TOPIC CONFIG (topic/dotsys.cfg)
-------------------------------
  
Specify a manager if required (default: none):
app: Use OS aplication manager
cmd: Use system command manager
topic_name: The name of any manager enabled topic

    manager: <app, cmd, topic_name>
    
Specify test to determine if topic is installed on system (default: topic directory name)
				            
    installed_test: <topic name>
    
Specify package name for all managers (default: topic directory name):

    package_name: <package name>
     				           
Specify the package name for specific manager:

    brew: <package name>
    	
Add topic dependencies (use topic directory names):

    deps:
      - <topic name>

Overide symlink destination (default: $HOME):
src_name: The repo source file name (no prefix or .symlink extension)
dst_name: The exact destination file name with prefix and extension

    symlinks:
      - src_name->$HOME/subdir/_dst_name
      
Install topic from a different repo:

    repo: user/repo_name


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