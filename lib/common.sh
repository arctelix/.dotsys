#!/bin/sh

# Global utility vars and methods
# Author: arctelix

# PATHS

full_path () {
  local file="$1"

  if [ "$PLATFORM" == 'freebsd' ]; then
    printf "$(realpath "$file")"
    return $?

  elif [ "$PLATFORM" == 'mac' ]; then
    local fp=$(readlink "$file")
    if [ ! "$?" ] || [ ! "$fp" ]; then
      [[ "$file" = /* ]] && printf "$file" || printf "${PWD}/${file#./}"
    else
      printf "$fp"
    fi
    return $?
  fi
  printf "$(readlink --canonicalize-existing "$file")"
}

dotfiles_dir () {
  echo "$(user_home_dir)/.dotfiles"
}

dotsys_dir () {
  echo "$(dotfiles_dir)/.dotsys"

}

# Gets full path to topic based on repo
topic_dir () {
  local topic="${1:-$topic}"
  local repo=$(get_topic_config_val "$topic" "repo")
  echo "$(repo_dir "$repo")/$topic"
}

# converts supplied repo or active repo to full path
repo_dir () {
    local repo="${1}"

    if ! [ "$repo" ]; then
        repo="$(get_active_repo)"
    fi

    if ! [ "$repo" ]; then
        return 1
    fi

    if [[ "$repo" = /* ]]; then
        echo "$repo"
    else
        echo "$(dotfiles_dir)/$repo"
    fi
}

builtin_topic_dir () {
  echo "$(dotfiles_dir)/.dotsys/builtins/$1"
}

topic_exists () {
  local topic="$1"
   # Verify built in or & user defined directories
  if ! [ -d "$(builtin_topic_dir $topic)" ] && ! [ -d "$(topic_dir $topic)" ]; then
    fail "$(printf "The topic, %b$topic%b, was not found in %b$(topic_dir $topic)%b" $green $rc $green $rc)"
    return 1
  fi
}

# Gets full path to users home directory based on platform
user_home_dir () {
  local platform="${1:-$PLATFORM}"

  case "$platform" in
    mac|linux|msys|cygwin|freebsd )
      echo "$HOME"
      ;;
    windows )
      echo "$(printf "%s" "$(cygpath --unix $USERPROFILE)")"
      ;;
    * )
      fail "$(printf "Cannot determine home directories for platform %b%s%b" $green "$platform" $rc)"
      ;;
  esac
}


# MISC TESTS

# Determines if a path is a file or a directory
path_type () {
  local type=
  if [ -d "$1" ];then
    type="directory"
  elif [ -f "$1" ];then
    type="file"
  fi
  echo "$type"
}

# Test for the existence of a command
cmd_exists() {
  command -v $1 >/dev/null 2>&1
}

# Test if script contains function
script_func_exists() {
  chmod +x $1
  $1 command -v $2 >/dev/null 2>&1
}

# Executes a function with params if a command exists
if_cmd() {
  if cmd_exists "$1"; then
    shift
    "$@"
  fi

}

# Executes a function with params if a command does not exist
if_not_cmd() {
  if ! cmd_exists "$1"; then
    shift
    "$@"
  fi
}

# MISC utils

# Gets the value of a dynamically named variable
# my_var=$(dv $dynmic_suffix)
dv (){
  echo ${!1}
}

# Exicutes a function in an external script
external_func () {
  if [ -f "$1" ]; then
    # source the script
    source "$1"
    shift
    if cmd_exists "$1"; then
      # exicute function
      "$@"
      return 100+$? # function error code
    else
      return 2 # function not found
    fi
  fi
  return 1 # file not found
}

# USAGE & HELP SYSTEM

# Shows local usage and usage_full text and exits script
show_usage () {

  while [[ $# > 0 ]]; do
    case "$1" in
      -f | --full   ) state="full" ;;
      * ) echo Invalid option: $1;;
    esac
    shift
  done

  printf "\n$usage\n"

  if [ "$state" = "full" ]; then
    printf "$usage_full\n"
  else
    printf "Use -h or --help for more.\n"
  fi
  exit
}

# Checks for a help param and shows help
# ex: check_for_help "$1"
check_for_help () {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_usage -f; fi
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
    error "Requires $required parameters and $# supplied."
    show_usage
  fi

}

# Confirms a list of var names are set
required_vars () {
local missing=
  for p in $@; do
    if ! [ "${!p}" ]; then
      missing+="<${p}> "
    fi
  done
  if [ "$missing" ]; then
    error "Missing or incorrect parameters $missing
    recieved: $@"
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
 local val="$1"
 shift
 local set_var=
 for p in "$@"; do
    if [[ "$val" == "-"* ]]; then
        printf "Invalid parameter '$val'"
        show_usage
    fi
    if ! [ "${!p}" ]; then
      local eval_exp="${p}=\"$val\""
      eval "$eval_exp"
      set_var="$p"
      break
    fi
 done

 if ! [ "$set_var" ]; then
   error "Too many params"
   show_usage
 fi
}

log () {
  printf "%b$@%b\n" $dark_gray $rc
}

is_array() {
  local var=$1
  [[ "$(declare -p $var)" =~ "declare -a" ]]
}

get_topic_list () {
    local dir="$1"
    if ! [ -d "$dir" ];then return 1;fi
    local topics=("$(find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')")
    local cleaned=()
    for t in ${topics[@]}
    do
        # remove path
        cleaned+=("${t##*/}")
    done
    echo "${cleaned[@]}"
}
