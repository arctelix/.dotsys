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
  echo "$DOTSYS_REPOSITORY"

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
  echo "$(dotsys_dir)/builtins/$1"
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
      chmod +x "$1"
      cmd_exists "$1"
      return $?
  fi
  return 1
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

topic_exists () {
  local topic="$1"
   # Verify built in or & user defined directories
  if ! [ -d "$(builtin_topic_dir $topic)" ] && ! [ -d "$(topic_dir $topic)" ]; then
    fail "$(printf "The topic %b$topic%b, was not found in the specified repo:
    $spacer %b$(topic_dir $topic)%b" $green $rc $green $rc)"
    msg "$spacer Check the topic spelling and make sure it's in the repo."
    return 1
  fi
}

# MISC utils

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

# Gets the value of a dynamically named variable
# my_var=$(dv $dynmic_suffix)
dv (){
  echo ${!1}
}

# Executes a function in an external script
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


is_array() {
  local var=$1
  [[ "$(declare -p $var)" =~ "declare -a" ]]
}

get_topic_list () {
    local dir="$1"
    if ! [ -d "$dir" ];then return 1;fi
    local topics=("$(find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')")
    local cleaned=()
    local t
    for t in ${topics[@]}
    do
        # remove path
        cleaned+=("${t##*/}")
    done
    echo "${cleaned[@]}"
}


