#!/bin/bash

# Core utilities
# Author: arctelix

# Make sure repo and library are available
if ! [ "$DOTSYS_REPOSITORY" ]; then
    export DOTSYS_REPOSITORY="$(dotsys repository)"
    export DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"
fi

# COLORS

black="\e[0;30m"
black_bold="\e[01;30m"

red="\e[0;31m"
dark_red="\e[01;31m"

green="\e[0;32m"
dark_green="\e[01;32m"

yellow="\e[0;33m"
dark_yellow="\e[01;33m"

blue="\e[0;34m"
dark_blue="\e[01;34m"

magenta="\e[0;35m"
dark_magenta="\e[01;35m"

cyan="\e[0;36m"
dark_cyan="\e[01;36m"

light_gray="\e[0;37m"
light_gray_bold="\e[01;37m"

dark_gray="\e[0;90m"
dark_gray_bold="\e[01;90m"

l_red="\e[0;91m"
l_red_bold="\e[01;91m"

l_green="\e[0;92m"
l_green_bold="\e[01;92m"

l_yellow="\e[0;93m"
l_yellow_bold="\e[01;93m"

l_blue="\e[94m"
l_blue_bold="\e[1;94m"

l_magenta="\e[0;95m"
l_magenta_bold="\e[01;95m"

l_cyan="\e[0;96m"
l_cyan_bold="\e[01;96m"

white="\e[0;97m"
white_bold="\e[01;97m"

rc="\e[0m" #reset color

clear_line="\r\e[K"
clear_line_above="\e[1A\r\e[K"

spacer="\r\e[K        " # indent from screen edge
indent="        " # indent from current position

c_debug="\e[0;90m"

# topic highlight color
hc_topic=""

# user color (normal)
c_user="\e[0m"
# user highlight color  (bold)
hc_user="\e[1m"

# default value color
c_default=$l_blue

# default value color
c_default=$l_blue

# code color
c_code=$magenta

# help color
c_help=$l_blue
hc_help=$dark_blue

#previous color
pc=

# DEBUGGING

DEBUG_IMPORT="false"

# Prints debug messages when DEBUG=true
debug () {
    if [ "$DEBUG" = true ]; then
        printf "%b%b%b\n" $c_debug "$1" $rc 1>&2
    fi
}

debug_import () {
    if [ "$DEBUG_IMPORT" = true ]; then
        printf "%b%b%b\n" $c_debug "$1" $rc 1>&2
    fi
}

# a print function that does not interfere with function output
dprint () {
    printf "%b%b%b\n" $c_debug "$1" $rc 1>&2
}

error () {
  printf  "\r\n%b%bERROR:  %b$*%b\n\n" $clear_line $dark_red $red $rc 1>&2
}

msg_warn () {
  printf  "\r%b%b%b%b\n" $clear_line $red "$1" $rc
}

# USAGE & HELP SYSTEM

# Display invalid option message and exit
invalid_option () {
    if ! [ "$1" ]; then return;fi
    error "invalid option: $1"
    show_usage
    exit
}

invalid_limit () {
    error "invalid limit: $1"
    show_usage
    exit
}

# Confirms provided param list is longer then a specified length.
# also checks for a help request
# Shows error with basic usage on fail
# ex: required_params 2 $@
required_params () {
  local required=$1
  shift
  check_for_help "$1"
  if ! (( $# >= $required )); then
    error "Requires ${#required} parameters and $# supplied."
    show_usage
  fi

}

# Confirms a list of var names are set
required_vars () {
  local missing=
  local recieved=
  local p
  for p in $@; do
    if ! [ "${!p}" ]; then
      missing+="<${p}> "
    else
      recieved+="<${p}> "
    fi
  done
  if [ "$missing" ]; then
    error "Missing or incorrect parameters $missing
    recieved: $recieved"
    show_usage
  fi
}

# A short cut method handle uncaught case
# Sets a specified list of variable names to the current param value.
# Catches invalid options (unspecified in case and prefixed with -).
# Catches too many params provided
# Displays error message and basic usage on fail
# ex: uncaught_case "$1" "var_name" "var_name"
uncaught_case (){
 local uc_c_val="$1"
 shift
 local set_var
 local uc_p_names="$@"
 local us_p_name

 # Skip blank values
 if [ ! "$uc_c_val" ];then return;fi

 for us_p_name in $uc_p_names; do
    if [[ "$uc_c_val" == "-"* ]]; then
        printf "Invalid parameter '$uc_c_val'"
        show_usage
    fi
    # if the supplied variable name is not set
    if [ -z "${!us_p_name}" ]; then
      local eval_exp="${us_p_name}=\"$uc_c_val\""
      eval "$eval_exp"
      set_var="$us_p_name"
      break
    fi
 done

 if [ -z "$set_var" ] && [ "$uc_c_val" ]; then
   local uc_c_vals=""
   for us_p_name in $uc_p_names;do
        uc_c_vals+="${us_p_name}=${!us_p_name}\n"
   done


   error "Too many params:
   \r${uc_c_vals}\rhave been set and got value: $uc_c_val"
   show_usage
 fi
}

# Check if next param is value or option
get_opt_val () {
    local next_val="$1"
    if [[ "$next_val" != "-"* ]]; then
        echo "$next_val"
    fi
}

# Shows local usage and usage_full text and exits script
show_usage () {

  while [[ $# > 0 ]]; do
    case "$1" in
      -f | --full   ) state="full" ;;
      * ) error "Invalid option for show usage: $1";;
    esac
    shift
  done

  echo "$usage" 1>&2

  if [ "$state" = "full" ]; then
    echo "$usage_full" 1>&2
  else
    echo "Use <command> -h or --help for more." 1>&2
  fi
  exit
}

# Checks for a help param and displays show_usage if available
# ex: check_forc_help "$1"
check_for_help () {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_usage -f; fi
}

not_implemented () {
    if [ "$DEBUG" = true ]; then
        printf "$spacer NOT IMPLEMENTED: %b$1 %b\n" $gray $rc
    fi
}

# BASIC FUNCTIONS & TESTS

pass (){
    return 0
}

# Capitolize first letter for string
cap_first () {
    echo `echo ${1:0:1} | tr  '[a-z]' '[A-Z]'`${1:1}
}

# Test for the existence of a command
cmd_exists() {
  if ! [ "$1" ];then return 1;fi
  command -v $1 >/dev/null 2>&1
}

# Test if script contains function
script_func_exists() {
  local rv
  local script="$1"
  local cmd="$2"
  shift;shift

  script_exists "$script"
  if ! [ $? -eq 0 ];then return 1;fi

  # Check for function definition in file
  # Not perfect, but may be faster then sourcing?
  #grep -q "$cmd *()" "$script"
  #return $?

  # Make sure the cmd is local function and not some other cmd.
  # Since were sourcing external scripts we'll test the same way
  # to avoid missing function errors
  (
  source "$script" >/dev/null 2>&1
  [ "$(command -v "$cmd")" = "$cmd" ]
  )
  rv=$?

  return $rv

}

# Source external script with internal "$@"
# This func required to insure intended params are executed
execute_script_func () {

  # Sourcing a file and executing in a subshell is now standard
  # rather then running commands in external script "$script" "@$"
  # This provides access to dotsys functions from external scripts

  local script="$1"
  shift

  ( source "$script" )
}

# Test if script exists
script_exists() {
  if [ -f "$1" ]; then
      chmod 755 "$1"
      return 0
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

# IMPORT

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

    local usage="import [source] <file> [<function>] [as <name>]"
    local usage_full="
        source      Source entire file (must be first argument)
        <file>      File to import
        <function>  Function to import
        as <name>   Local reference the imported file or function
    "

    check_for_help "$1"

    local src
    if [ "$1" = "source" ]; then src="true"; shift; fi

    local func_name
    local import_func_name
    local file_name="$1"
    local file_path="$DOTSYS_LIBRARY/${file_name}.sh"
    shift

    while [[ $# > 0 ]]; do
        case "$1" in
        as )      import_func_name="$2"; shift ;;
        *)        func_name="$1";; # DO NOT USE uncaught_case here (zsh fails)
        esac
        shift
    done

    debug_import "=import=> $file_name $func_name"

    # if local func exists nothing to do
    if [ "$func_name" ] && cmd_exists "$func_name" ; then
        debug_import "          <= already imported $func_name"
        return
    elif ! [ "$func_name" ] && cmd_exists "imported_$file_name" ; then
        debug_import "          <= already imported $file_name"
        return
    fi

    # test for script
    if ! script_exists "$file_path" ; then
        echo "IMPORT ERROR: file does not exist : '$file_path'" 1>&2
        return

    # test for script func
    elif [ "$func_name" ] && ! script_func_exists "$file_path" "$func_name"; then
        echo "IMPORT ERROR: function '$func_name' does not exist in '$file_name'" 1>&2
        return
    fi

    # source: sources script and creates a placeholder function
    # causing a second call to import source to be aborted.

    if [ "$source" ]; then
        debug_import "importing source $file_name $func_name"
        source "$script"
        eval "${file_name}() {
                  debug_import \"call sourced $file_name : \$@ \"
                  \"\$@\"
        }"
        return
    fi

    # import: executes script functions in a sub-shell preventing
    # inadvertent local name collisions & pollution.

    if [ "$func_name" ]; then
        debug_import "          -> importing func $file_name $func_name as ${import_func_name:-$func_name}"
        eval "${import_func_name:-$func_name} () {
              debug_import \"**called ${import_func_name:-$func_name} : \"\$@\" \"
              # Source file into subshell and execute function
              ( source $file_path; $func_name \"\$@\" )
        }"
    else
        debug_import "          -> importing module $file_name as ${import_func_name:-$file_name}"
        eval "${import_func_name:-$file_name} () {
              debug_import \"**called ${import_func_name:-$file_name} : \$* \"
              # Source file into subshell and execute function
              ( source $file_path; \"\$@\" )
        }"
    fi

}


