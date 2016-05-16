#!/bin/sh

# Global utility vars and methods
# Author: arctelix

# PATHS

drealpath(){
    sh "$DOTSYS_LIBRARY/drealpath" $@
}


dotfiles_dir () {
  echo "$(user_home_dir)/.dotfiles"
}

dotsys_dir () {
  echo "$DOTSYS_REPOSITORY"

}

# Gets full path to topic based on active repo
topic_dir () {
  local topic="${1:-$topic}"
  local repo=$(get_topic_config_val "$topic" "repo")

  # catch dotsys as topic
  if [ "$topic" = "dotsys" ]; then
      echo "$(builtin_topic_dir "$topic")"
      return
  fi

  echo "$(repo_dir "$repo")/$topic"
}

# converts supplied repo or active repo to full path
repo_dir () {
    local repo="${1}"
    local branch

    if ! [ "$repo" ]; then
        repo="$(get_active_repo)"
    fi

    if ! [ "$repo" ]; then
        return 1
    fi

    # catch dotsys repo
    if [ "$repo" = "dotsys/dotsys" ]; then
        repo="$(drealpath "$DOTSYS_REPOSITORY")"
    fi

    _split_repo_branch

    # catch abs path
    if [[ "$repo" = /* ]]; then
        echo "$repo"
    # relative to full path
    else
        echo "$(dotfiles_dir)/$repo"
    fi
}

# seperate repo:branch into repo and branch
# requires predefined local vars "repo" and "branch"
_split_repo_branch () {
    # [^/]+/[^/]+/[^/]+$ = user/repo/master[end]
    if [[ "$repo" =~ .+/.+:.+ ]]; then
        branch="${repo##*:}"
        repo="${repo%:*}"
    fi
}

builtin_topic_dir () {
  echo "$(dotsys_dir)/builtins/$1"
}

dotsys_user_bin () {
  echo "$(dotsys_dir)/user/bin"
}

# MISC TESTS

# Test for VERBOSE_MODE
verbose_mode (){
    if ! [ "$VERBOSE_MODE" ]; then
        if ! [ "$topics" ] || [ ${#topics[@]} -gt 1 ]; then
            # verbose on
            VERBOSE_MODE=0
        else
            # verbose off
            VERBOSE_MODE=1
        fi
    fi
    return $VERBOSE_MODE
}

dry_run (){
    local state="$1"
    if [ "$state" ]; then
        DRY_RUN_STATE=0
        DRY_RUN="(dry run)"
    fi
    return $DRY_RUN_STATE
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
      chmod +x "$1"
      cmd_exists "$1"
      return $?
  fi
  return 1
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

# not used
is_array() {
  local var=$1
  [[ "$(declare -p $var)" =~ "declare -a" ]]
}


in_limits () {
    local tests=$@
    local option
    tests=
    while [[ $# > 0 ]]; do
        case $1 in
        -r | --required)  option="required";;
        * )   tests+="$1 "      ;;
        esac
        shift
    done

    # No limits = everything in limits unless required
    if [ "$option" != "required" ] && ! [ "$limits" ]; then
        return 0
    fi

    local t
    for t in $tests; do
        debug "  - testing: $t"
        if [[ ${limits[@]} =~ "$t" ]]; then
            debug "   - in limits: $t"
            return 0
        fi
    done
    debug "   - not in limits: $tests"
    return 1
}

topic_is_repo () {
    [ "${topics[0]}" = "repo" ] && topics[0]="$(get_active_repo)" || [[ "${topics[0]}" == *"/"* ]]
}


# MISC utils

# Determines if a path is a file or a directory
path_type () {
  local type="\b"

  if [ -L "$1" ];then
    type="symlinked"
  fi

  if [ -d "$1" ];then
    type="$type directory"
  elif [ -f "$1" ];then
    type="$type file"
  fi

  echo "$type"
}


# Executes a function in an external script
# not used
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

get_dir_list () {
    local dir="$1"
    local force="$2"
    local list
    local t

    if ! [ -d "$dir" ];then return 1;fi
    list="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')"

    for t in ${list[@]}; do
        echo "$(basename "$t") "
    done
}

get_topic_list () {
    local dir="$1"
    local force="$2"
    local list
    local topic


    # only installed topics when not installing unless forced
    if [ "$action" != "install" ] && ! [ "$force" ]; then
        while read line; do
            topic=${line%:*}
            # skip system keys
            if [[ "$STATE_SYSTEM_KEYS" =~ $topic ]]; then continue; fi
            echo "$topic"
        done < "$(state_file "dotsys")"
    # all defined topic directories
    else
        if ! [ -d "$dir" ];then return 1;fi
        get_dir_list "$dir"
    fi
}

get_installed_topic_paths () {
    local list
    local topic
    local repo

    while read line; do
        topic=${line%:*}
        repo=${line#*:}
        # skip system keys
        if [[ "$STATE_SYSTEM_KEYS" =~ $topic ]]; then continue; fi
        echo "$repo/$topic"
    done < "$(state_file "dotsys")"
}

rename_all() {
    local files="$(find "$1" -type f -name "$2")"
    local file
    local new
    while IFS=$'\n' read -r file; do
        new="$(dirname "$file")/$3"
        get_user_input "rename $file -> $new"
        mv "$file" "$new"
    done <<< "$files"
}

#Reverse order of array
#USAGE: reverse arrayname
#TODO: IMPLIMENT REVERSE TOPICS FOR UNINSTALL
reverse() {
    local arrayname=${1:?Array name required}
    local array
    local revarray
    local e

    #Copy the array, $arrayname, to local array
    eval "array=( \"\${$arrayname[@]}\" )"

    #Copy elements to revarray in reverse order
    for e in "${array[@]}"; do
    revarray=( "$e" "${revarray[@]}" )
    done

    #Copy revarray back to $arrayname
    eval "$arrayname=( \"\${revarray[@]}\" )"
}




