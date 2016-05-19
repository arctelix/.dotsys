TOPIC CONFIG (topic/dotsys.cfg)
-------------------------------

repo: user/repo_name 				        # change repo to install from
manager: cmd 					            # specify a manager ([none], app, cmd, topic )
installed_test: [shell test] 			    # test determines if installed on system by other means (default: is_cmd $topic)
name: package_name 				            # manager package name if not (default: topic name)
brew: package_name 				            # specific manager package name ex: brew: python,  pact: python2
deps:						                # list topic dependancies
  - topic_name
symlinks:  					                # set symlink alternate path/name (default: $HOME)
  - file.symlink->$HOME/subdir/_file 		# alternate path/name for file.symlink


MANAGER CONFIG OPTIONS
----------------------
manager: app 					        # system manger ie: cask, chocolaty, yum
manager: cmd 					        # envrionment manager ie: brew, scoop,
manager: both 					        # install with both (TODO: not implimented)
manager: npm 					        # any topic can be a manager if it does the folowing


PLATFORM CONFIG OPTIONS
-----------------------

# full platform name (do not use in config files)
linux-mac:
windows-cygwin:

mac:                                          # specific platform name (only linux-mac)
cygwin:                                       # specific platform name (only windows-cygwin)

# generic platform name
windows:                                      # applies to all windows platforms
linux:                                        # applies to all linux platforms

# Include/exclude for platform (use 'x' to exclude and 'i' to include)
# any platform not excluded generically or specifically will be installed
# when a generic platform is excluded you must explicitly include any specific platforms you want to use

linux: x                                      # exclude all linux platforms
mac: i                                        # override include linux-mac


TOPIC CONFIG: PLATFORM SPECIFIC (windoes/mac/linux/freebsd/mysys)
-----------------------------------------------------------------
# All base config settings are applicable as platform children and will supersede the base config

windows: i 					                # include all windows platforms
  manager: app 					            # override manager for platform
  repo: user/repo_name			      	    # override repo for platform
  symlinks: 					            # set paths for platform
    - file.symlink->$HOME/subdir/_file  	# set file specific path for platform

linux: x                                    # exclude all other linux platforms


EXAMPLE TYPICAL TOPIC (vim)
---------------------------

manager: cmd
brew: macvim
  installed_test: mvim
windows:
  symlinks:
    - vimrc.symlink -> $HOME/_vimrc


# REPO CONFIG (user/repo/dotsys.cfg)

repo: user_name/repo_name\[:branch\]	# default repo for all topics (branch is optional, defaults to master)
					
windows:					            # platform manger overrides for windows(defaults shown)
  app_manager: choco
  cmd_manager: pact
mac:                                    # platform manger overrides for mac (defaults shown)
  app_manager: cask
  cmd_manager: brew


REPO CONFIG TOPIC OVERRIDES
---------------------------
# all topic child settings apply

topic1:  					          # include
  repo: alternate/repo				  # alternate repo for topic
  windows: x					      # exclude on windows platforms
topic2: x  					          # exclude all platforms

INCLUDE / EXCLUDE RULES
-----------------------

package: i              # include all subs
  file1:                # include
  file2: x              # include
  file3: i              # include

package: x              # exclude all subs
  file1:                # exclude
  file2: x              # exclude
  file3: i              # exclude

package:                # limited install
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

*.symlink 					# a symlink file
*.shell 					# sourced by all shells
*.$topic                    # sourced by topic
topic/bin 					# files are symlinked to user/bin


TODO: SETTINGS (*.settings)
---------------------------

# ex: finder.settings file defines individual functions for each setting
show_hiden_files (){
  commands to execute
}
# ex: dock.settings file defines individual functions for each setting
auto_hide (){
  commands to execute
}

# Now each setting can be controlled by cfg file

settings_windows: i	       # all child settings installed despite individual settings
settings_osx:
  dock: i			# all child settings installed despite individual settings
    auto_hide: x              # installed due to parent override
  finder: 			# check individual settings
    show_hidden_files: i      # included
    as_list: x			# excluded
settings_windows:
settings_freebsd:
settings_linux:


TODO (maybe) OS SPECIFIC SCRIPTS
--------------------------------
# topic.sh 
  platform function prefix ex: mac_install

# install, update, uninstall
  *.sh.os (platform extension, executes first only for platform)
  install.sh (applies to all os)
  uninstall.sh (applies to all os)
  update.sh (applies to all os)
# equivalent dotsys.yaml
  all: yes
    install: some command
    uninstall: some command
    update: some command
  platform: yes
    install: some command
    uninstall: some command
    update: some command




