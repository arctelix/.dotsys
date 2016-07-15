#!/bin/bash

# Common tests
# Author: arctelix

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
        branch="${repo#*:}"
        repo="${repo%:*}"
    fi
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

topic_exists () {
  local topic="$1"
  local restrict="$2"
  local ret=0

  # Verify user defined directories
  if [ "$restrict" ] && ! [ -d "$(topic_dir $topic "$restrict")" ]; then
    if ! [ "$recursive" ];then
        fail "The topic" "$(printf "%b$topic" "$hc_topic")" ",was not found in repo:
        $spacer $(topic_dir $topic "$restrict")"
    fi
    ret=1

  # Verify built in or & user defined directories
  elif ! [ -d "$(topic_dir $topic)" ]; then
    if ! [ "$recursive" ];then
        fail "The topic" "$(printf "%b$topic" "$hc_topic")" ",was not found in dotsys builtins or repo:
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

# no args : checks if there there any user installed topics
# topic as first arg : test if topic is user installed
user_topics_installed () {
    in_state "dotsys" "$1" "!dotsys/dotsys"
    local r=$?
    debug "   - user_topics_installed = $r"
    return $r
}

# Check if topic is required by dotsys
is_required_topic () {
    local topic="${1:-$topic}"
    ! in_limits "dotsys" -r && in_state "dotsys" "$topic" "dotsys/dotsys"
    local r=$?
    debug "   - is_required_topic = $r"
    return $r
}

# Check if topic has required stub file
is_required_stub () {
    local topic="${1:-$topic}"
    ! in_limits "dotsys" -r && [ "$topic" = shell ]
    local r=$?
    debug "   - is_required_stub = $r"
    return $r
}

is_shell_topic () {
    local topic="${1:-$topic}"
    [[ "shell bash zsh ksh" =~ $topic ]]
}

# Executes commands as sudo only when necessary
dsudo () {

    # Check for real sudo (windows is bs)
    if ! sudo -h >/dev/null 2>&1 ; then "$@"; return $?; fi

    local result
    local rv
    result="$("$@" >/dev/null 2>&1)"
    rv=$?

    # Get sudo password if cmd fails and is required
    if ! [ $rv -eq 0 ] && ! sudo -n true >/dev/null 2>&1; then
        task "The admin password is required to alter some files"
        sudo -v -p "$(printf "$spacer Enter password : ")"
    fi

    # Try sudo if original failed
    if ! [ $rv -eq 0 ];then
        sudo "$@"

    # echo the original result on success
    elif [ "$result" ];then
        echo "$result"
    fi

    return $?
}

