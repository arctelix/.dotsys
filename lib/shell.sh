#!/bin/sh

# Shell functions
# Author: arctelix

import platforms
import state

shell_debug () {
    if [ "$DEBUG_SHELL" = true ]; then
        printf "%b%b%b\n" "\e[0;92m" "$1" "\e[0m" 1>&2
    fi
}

# Sets global flag for shell reload when topic matches "shell" or $active_shell
flag_reload () {
    local topic="$1"
    local flagged="$2"
    local active_shell="$ACTIVE_SHELL"
    local state=1

    # Test if topic is current_shell or "required"
    if [ "$topic" = "$active_shell" ] || [ "$topic" = "shell" ];then
        state=0
        flagged="$topic"
        debug "FLAG RELOAD SHELL ($state): $flagged"
    fi
    echo "$flagged"
    return $state
}

# Resources active shell files
# Supply topic for test only
# Supply "now" to bypass checks
reload () {

    if [ "$ACTIVE_LOGIN_SHELL" ];then
        exec -l "$ACTIVE_SHELL"
    elif [ "$ACTIVE_SHELL" ]; then
        exec "$ACTIVE_SHELL"
    else
        exec "$SHELL" -l
    fi

    # Remove flag for reload
    export RELOAD_SHELL=""
}


# Sources all required files for shell initialization
# all login shell init files must call this function
shell_init() {

    local shell="$(get_active "$1")"
    local file="$2"
    local login="$3"

    # Abort if active or spcified shell already initialized
    if [ "$SHELL_INITIALISED" = "$shell" ];then
        echo "already initialized $shell" 1>&2
        return
    fi

    shell_debug "INITIALIZEING $shell $login from $file"
    #shell_debug "  shell:$shell file:$file"
    #shell_debug "  profile:$profile rc:$shellrc"

    # Change shells requires new environment
    if [ "$ACTIVE_SHELL" ] && [ "$ACTIVE_SHELL" != "$shell" ];then
        unset ACTIVE_SHELL
        echo "exec $shell" 1>&2
        if [ "$ACTIVE_LOGIN_SHELL" ] || [ "$login" ];then
            exec $shell -l
        else
            exec $shell
        fi
        echo "exec $shell complete" 1>&2
    fi

    SHELL_INITIALISED="$shell"

    set_prompt "$shell"

    local home="$(platforms platform_user_home)"
    local profile="$(get_file "profile" "$shell")"
    local shellrc="$(get_file "rcfile" "$shell")"
    local loaded_files
    loaded_files=("$file")

    ACTIVE_SHELL="$SHELL_INITIALISED"

    # load global rc file
    [ "$file" != ".shellrc" ] && load_source_file "$home/.shellrc" "RCFILE"

    # Load shells unique rc file ie:.zshrc if it exists
    [ "$file" != "$shellrc" ] && load_source_file "$home/$shellrc" "RCFILE"

    if [ "$login" ];then

        ACTIVE_LOGIN_SHELL="$SHELL_INITIALISED"

        # Load global .profile if it exists
        [ "$file" != ".profile" ] && load_source_file "$home/.profile" "PROFILE"

        # Load shells unique profile ie:.zsh_profile if it exists
        [ "$file" != "$profile" ] && load_source_file "$home/$profile" "PROFILE"

        shell_debug "> LOADING PROFILE $file"
    else
        shell_debug "> LOADING RCFILE $file"
    fi

    export SHELL_FILES_LOADED="${loaded_files[*]}"
}

load_source_file(){
    local file="$1"
    local init_file="$2"
    local file_name="$(basename "$file")"

    if [ ! -f "$file" ]; then return;fi

    if [ "$init_file" ]; then
        shell_debug "> LOADING $init_file $file_name"
    else
        shell_debug "  - loading $file_name"
    fi
    source "$file"
    loaded_files+=("$file_name")
}


# Native shell init files (for reference)
# bash )  shellrc=".bashrc";   profile=".bash_profile";;
# zsh  )  shellrc=".zshrc";    profile=".zprofile";;
# ksh  )  shellrc=".kshrc";    profile=".profile";;
# csh  )  shellrc=".cshrc";    profile=".login";;
# tcsh )  shellrc=".tcshrc";   profile=".login";;

# Retrieves the correct shellrc or profile for each shell
# We implement separate profiles for each shell users should
# customize thees files when there are shell specific requirements
get_file () {
    local file="$1"
    local shell="${2:-"$ACTIVE_SHELL"}"
    local rcfile
    local profile

    case "$shell" in
        bash )  rcfile=".bashrc";   profile=".bash_profile";;
        zsh  )  rcfile=".zshrc";    profile=".zsh_profile";;
        ksh  )  rcfile=".kshrc";    profile=".ksh_profile";;
        csh  )  rcfile=".cshrc";    profile=".csh_login";;
        tcsh )  rcfile=".tcshrc";   profile=".tcsh_login";;
    esac

    if [ "$file" = "profile" ]; then
        echo "$profile"
    else
        echo "$rcfile"
    fi
}


# Determine active shell from input
# Root shell can use "shell" determine automatically
get_active () {

    local input="$1"
    local result

    if ! [ "$input" ] && [ "$ACTIVE_SHELL" ]; then echo "$ACTIVE_SHELL"; return; fi

    # Try to parse $0 or parse from error message
    if [ "$input" = "shell" ]; then
        result="$(shell_from_string "$0" || shell_from_string "$(error_string 2>&1)")"

    # Parse shell name from input
    else
        result="$(shell_from_string "$input")"
    fi

    echo "${result:-unknown}"

}

# Parse input string for shell name
shell_from_string() {
    local result
    case "$1" in
        *bash* )    result=bash;;
        *zsh*  )    result=zsh;;
        *ksh*  )    result=ksh;;
        *csh*  )    result=csh;;
        *tcsh* )    result=tcsh;;
        shell  )    result=shell;;
    esac
    echo "$result"
    [ "$result" ]
}

is_shell_topic () {
    local topic="${1:-$topic}"
    shell_from_string "$topic"
}


# Sets the dotsys prompt for each shel
set_prompt () {
    local shell="${1:-$ACTIVE_SHELL}"

    # Only use dotsys prompt if enabled by user
    if ! state get_state_value "dotsys" "dsprompt";then return;fi

    if [ "$shell" = "zsh" ];then
        autoload -Uz colors && colors
        PROMPT="$fg[green]|DS|$reset_color $PROMPT"

    else
        PS1="\e[0;92m|DS|\e[0m $PS1"
    fi
}