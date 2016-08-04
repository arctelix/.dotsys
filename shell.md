Shell System
============

When dotsys is installed it will automatically detect the current shell and logically
source all applicable config files.  In addition to the current shell's normal config
files there are two generic `shell` config files that will always be sourced first.

    .shellrc  - then -> active shell's rc file (sourced by all shells)
    .profile  - then -> active shell's profile (sourced by login shells only)

All common configuration should go in your shell/shellrc.symlink and any additional common
config for login shells should  go in shell/profile.symlink. Any code in these files must
be POSIX compliant.

Only code intended for a specific shell such as bash or zsh should go in their respective
rc files and profiles.

In addition to clear organization of config files, there are many useful utilities, helper
functions, and variables available in your shell environment.

Shell startup flow
------------------

The first config file to be called by the current active shell will kick of the load process
with the following line.

    INIT_SHELL="shell_name .file_name "; $(dotsys source init_shell) || return

All code after this line (including your symlinks) will have access to the contents of `core.sh`
& `shell.sh`.  The primary functions responsible for shell loading are:

1) init_shell.sh        : Sources required files, controls file execution, and calls ->
2) shell.sh/shell_init  : Loads required config files and sets environment flags

shellrc.stub
------------
  
Provides useful variables and aliases for all shell environment (bash, zsh, ksh, etc).

#### VARIABLES: 

These variables should be usedin your dotfiles rather then hard coding them. 

$PLATFORM : Active platform (full) ie: linux-mac, windows-cygwin<BR>
$PLATFORM_S : Active platform (specific) ie: mac, freebsd, cygwin<BR>
$PLATFORM_G : Active platform (generic) ie: linux, windows<BR>
ACTIVE_SHELL : The currently active shell<BR>
$DOTFILE_DIR: Your .dotfiles directory<BR>
$DOTSYS_USER_BIN : Where all your bin/* files are symlinked to<BR>
$PLATFORM_USER_HOME : The platform specific user home directory<BR>
$PLATFORM_USER_BIN : The platform specific user bin directory<BR>

#### ALIASES

dfd : cd to your Dotfiles Directory (.dotfiles)<br>
sfl : Sourced Files List (all currently sourced files in shell env)<br>
din : dotsys install<br>
dun : dotsys uninstall<br>
dug : dotsys upgrade<br>
dud : dotsys update<br>
dfr : dotsys freeze<br>

see ~/.shellrc for more

#### YOUR SHELL CUSTOMIZATIONS

Place your customizations that are NOT TOPIC or SHELL specific in `user/repo/shell/shellrc.symlink`.
and topic related items that are not shell specific in `user/repo/topic_name_/file_name.shell`.

#### POSIX ONLY

Please use only POSIX compliant commands for the generic shell environment and use
shell specific rc files for shell specific customizations, such as bashrc & zshrc.

core.sh
-------

Provides core utilities used throughout dotsys that could be useful in your config files. Most
importantly, the import function, which allows you to utilize any dotsys function in any file.

import : Creates a local reference to an external script or script function.  Since functions are
called in the context of the module you don't need to worry about internal dependencies

    # Import utils module
    import utils
    utils fix_crlf .

    # Import escape_sed form utils
    import utils escape_sed
    sed -i -- "s|$(echo "$find" | escape_sed)|$(echo "$rep" | escape_sed)|g" "$file"

    # Import replace_file_string from utils as rfs
    import utils replace_file_string as rfs
    rfs "$file" "replace me" "replaced"

see .dotsys/lib/core.sh for more


shell.sh
--------

Functions for managing the shell environment

shell_reload         : Reloads the current shell environment
shell_init <shell>   : Initialize a different shell
shell_prompt <state> : Turn dotsys prompt prefix on or off
shell_debug          : Toggle shell debug mode

NOTE: When the shell system is active you will not be able to re-source system config files
from the command line with `source .bashrc`.  Use `shell_reload` to reload all required files.

see .dotsys/lib/shell.sh for more


