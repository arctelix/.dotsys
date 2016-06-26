#!/bin/sh

# Core utilities
# Author: arctelix


# Make sure repo and library are available
if ! [ "$DOTSYS_REPOSITORY" ]; then
    export DOTSYS_REPOSITORY="$(dotsys repository)"
    export DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"
fi

debug_text="\e[0;90m"
rc="\e[0m" #reset color

# Prints debug messages when DEBUG=true
debug () {
    if [ "$DEBUG" = true ]; then
        printf "%b%b%b\n" $debug_text "$1" $rc 1>&2
    fi
}

# a print function that does not interfere with function output
print () {
    printf "%b%b%b\n" $debug_text "$1" $rc 1>&2
}


not_implemented () {
    if [ "$DEBUG" = true ]; then
        printf "$spacer NOT IMPLEMENTED: %b$1 %b\n" $gray $rc
    fi
}

pass (){
    return 0
}

# Test for the existence of a command
cmd_exists() {
  if ! [ "$1" ];then return 1;fi
  command -v $1 >/dev/null 2>&1
}

# Test if script contains function
script_func_exists() {
  script_exists "$1"
  $1 command -v $2 >/dev/null 2>&1
}

# Test if script exists
script_exists() {
  if [ -f "$1" ]; then
      chmod u+x "$1"
      cmd_exists "$1"
      return $?
  fi
  return 1
}

# Determines if a path is a file, directory, or orphaned symlink
path_type () {
  local type="\b"

  if [ -L "$1" ];then
    type="symlinked"
  fi

  if [ -d "$1" ];then
    type="$type directory"
  elif [ -f "$1" ];then
    type="$type file"
  elif [ -L "$1" ];then
    type="orphaned symlink"
  fi

  echo "$type"
}

# Creates a local function to call an external script's functions without
# polluting the local scope with all of the external function names.
# Also allows for sourcing external scripts without redundancy.

# external script (only script name available locally):
# import platforms
# PLATFORM="$(platforms get_platform)"

# external script function (only imported function name available locally):
# import platforms get_platform
# PLATFORM="$(get_platform)"

# source external script (makes all functions available locally):
# import source platforms
# PLATFORM="$(get_platform)"
import () {

    usage="import [source] <file> [<function>]"
    usage_full="
        source  Source entire file
        file    File to import
        func    Function to import
    "
    local source

    if [ "$1" = "source" ]; then
        source="true"
        shift
    fi

    local file_name="$1"
    local script="$DOTSYS_LIBRARY/${file_name}.sh"
    local func_name="$2"

    # if local func exists nothing to do
    if [ "$func_name" ] && cmd_exists "$func_name" ; then
        debug "already imported $func_name"
        return
    elif ! [ "$func_name" ] && cmd_exists "$file_name" ; then
        debug "already imported $file_name"
        return
    fi

    # test for script
    if ! script_exists "$script" ; then
        echo "IMPORT ERROR: $file_name does not exist"

    # test for script func
    elif [ "$func_name" ] && ! script_func_exists "$script" "$func_name"; then
        echo "IMPORT ERROR: $file_name $func_name does not exist"
    fi


    # source: sources script and creates a placeholder function
    # causing a second call to import source to be aborted.

    if [ "$source" ]; then
        debug "importing source $file_name $func_name"
        source "$script"
        eval "${file_name}() {
                  debug \"call sourced $file_name : \$@ \"
                  \"\$@\"
        }"
        return
    fi

    # import: executes script functions in a sub-shell preventing
    # inadvertant local name collisions.

    if [ "$func_name" ]; then
        debug "importing $func_name"
        eval "${func_name}() {
              debug \"call $func_name : \$@\"
              # Source file into subshell and execute function
              ( source \"$script\"; $func_name \"\$@\" )
        }"
    else
        debug "importing $file_name"
        eval "${file_name}() {
              debug \"call $file_name : \$@ \"
              # Source file into subshell and execute function
              ( source \"$script\"; \"\$@\" )
        }"
    fi

}


