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

# Gets full path to topic based on topic config repo or active repo
# restrict:
# 'active'  Restrict to active user repo (do not check builtins)
# 'builtin' Restrict to builtin repo
# 'primary' Restrict to primary repo
# 'user'    Restrict to any user repo topic config repo or active repo or primary repo
topic_dir () {
    local topic="${1:-$topic}"
    local restrict="$2"
    local return_non_exist="$3"
    local path

    #debug "   - topic_dir $restrict:"

    # Installed repo (not dotsys)
    local repo="$(get_state_value "dotsys" "$topic" "!dotsys/dotsys")"

    if ! [ "$repo" ]; then
        # Check for topic alternate repo
        repo=$(get_topic_config_val "$topic" "repo")
        # use active repo if topic repo not found
        repo="${repo:-$(get_active_repo)}"
    fi

    # Do not use dotsys repo (default to primary repo)
    if [ "$restrict" = "user" ]; then
        if is_dotsys_repo; then
           repo="$(state_primary_repo)"
        fi

    # Restrict to primary
    elif [ "$restrict" = "primary" ]; then
        repo="$(state_primary_repo)"

    # Non restricted (installed, topic cfg, active, builtin)
    elif [ "$restrict" != "active" ]; then
        path="$(repo_dir "$repo")/$topic"
        if [ ! -d "$path" ]; then
            path="$(builtin_topic_dir "$topic")"
        fi
    fi

    # catch dotsys repo or well get .dotsys dir not builtins
    if is_dotsys_repo || [ "$restrict" = "builtin" ]; then
        path="$(builtin_topic_dir "$topic")"

    elif ! [ "$path" ]; then
        path="$(repo_dir "$repo")/$topic"
    fi

    # Return bad path when user requested and does not exist
    if ! [ -d "$path" ] && ! [ "$restrict" = "user" ]; then
        #debug "   -> PATH NOT FOUND $repo + $topic = $path"
        echo ""
        return 1
    else
        #debug "   -> FOUND $repo + $topic = $path"
        echo "$path"
    fi
    return 0
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
    if is_dotsys_repo; then
        # Git is in root not builtins
        repo="$DOTSYS_REPOSITORY"
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

# determines the active repo config -> state
get_active_repo () {
  if [ "$ACTIVE_REPO" ]; then
    echo "$ACTIVE_REPO"
    return
  fi

  # check for config file repo
  #local repo="$(get_config_val "_repo")"

  # state primary repo
  if ! [ "$repo" ]; then
      repo="$(state_primary_repo)"
  fi
  echo "$repo"

}

is_dotsys_repo () {
    local repo="${1:-$repo}"
    [ "$repo" = "dotsys/dotsys" ] || [ "$repo" = "$(dotsys_dir)/builtins" ]
    return $?
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

get_user_stub_file() {
    local topic="$1"
    local stub_src="$2"
    local stub_name="$(basename "${stub_src%.*}")"
    echo "$(user_stub_dir)/${stub_name}.${topic}.stub"
}

user_stub_dir() {
    echo "$(dotsys_dir)/user/stubs"
}

get_topic_or_builtin_file () {
    local topic="$1"
    local find_file="$2"
    local t_dir="$(topic_dir "$topic")"

    # check user directory for file
    if [ -d "$t_dir" ]; then
        file="$(find "$t_dir" -mindepth 1 -maxdepth 1 -type f -name "$find_file" )"
    fi

    # check builtin directory for file
    if ! [ "$file" ];then
        local b_dir="$(topic_dir "$topic" "builtin")"
        if [ -d "$b_dir" ]; then
            file="$(find "$b_dir" -mindepth 1 -maxdepth 1 -type f -name "$find_file" )"
        fi
    fi

    echo "$file"
    script_exists "$file"
    return $?
}


# MISC TESTS

# Test for VERBOSE_MODE
verbose_mode (){
    local vm
    if ! [ "$VERBOSE_MODE" ] || [ "$recursive" ]; then

        if ! [ "$topics" ] && ! in_limits "repo" -r; then
            # verbose on
            vm=0
        else
            # verbose off
            vm=1
        fi
    fi

    if ! [ "$VERBOSE_MODE" ]; then
        VERBOSE_MODE=$vm
    fi

    return ${vm:-$VERBOSE_MODE}
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
  local restrict="$2"
  local ret=0

  # Verify user defined directories
  if [ "$restrict" ] && ! [ -d "$(topic_dir $topic "$restrict")" ]; then
    if ! [ "$recursive" ];then
        fail "The topic" "$(printf "%b$topic" $thc)" ",was not found in repo:
        $spacer $(topic_dir $topic "$restrict")"
    fi
    ret=1

  # Verify built in or & user defined directories
  elif ! [ -d "$(topic_dir $topic)" ]; then
    if ! [ "$recursive" ];then
        fail "The topic" "$(printf "%b$topic" $thc)" ",was not found in dotsys builtins or repo:
        $spacer $(topic_dir $topic "active") $ACTIVE_REPO"
    fi
    ret=1
  fi

  if ! [ "$recursive" ] && [ $ret -eq 1 ];then
    #if ! [ "$recursive" ];then
        #debug "  - topic_exists: ($topic) not found recursive bypass message"
        msg "$spacer Check the topic spelling and make sure it's in the repo."
    #fi
  fi

  return $ret


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
        if [[ ${limits[@]} =~ "$t" ]]; then
            debug "   - is in_limits: $t"
            return 0
        fi
        debug "   - not in_limits: $tests"
    done

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
  elif [ -L "$1" ];then
    type="unused symlink"
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

# Returns a list directory names in a directory
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

# rename all files in a directory matching a name
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
#USAGE: reverse_array arrayname
reverse_array() {
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


#Test if value is in an array
#USAGE: array_contains arrayname
array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

# return a list of unique values
unique_list () {
    local var="$1"
    local seen
    local word

    for word in $var; do
      case $seen in
        $word\ * | *\ $word | *\ $word\ * | $word)
          # already seen
          ;;
        *)
          seen="$seen $word"
          ;;
      esac
    done
    echo $seen
}

remove_from_file () {
    local file="$1"
    local remove="$2"
    ex "+g|$remove|d" -cwq "$file"
}


