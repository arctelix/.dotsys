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

    INIT_SHELL="shell_name .file_name "; source "$(dotsys source init_shell)" || return

All code after this line (including your symlinks) will have access to the contents of `core.sh`
& `shell.sh`.  The primary functions responsible for shell loading are:

1) init_shell.sh        : Sources required files, controls file execution, and calls ->
2) shell.sh/shell_init  : Loads required config files and sets environment flags

shellrc.stub
------------
  
Provides useful variables and aliases that will be available to all dotsys files such as topic.sh
and manager.sh files.

$PLATFORM_SPE    :  Active platform (specific) such as mac, freebsd, cygwin
$PLATFORM_GNE    :  Active platform (generic) such as linux or windows
$ACTIVE_SHELL    :  The currently active shell name

dfd              :  cd to your .dotfiles directory
sfl              :  list all the currently sourced files in the shell environment

see ~/.shellrc for more


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
from the command line ie: `source .bashrc`.  Use `shell_reload` to reload all required files.

see .dotsys/lib/shell.sh for more


