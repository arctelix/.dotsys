#!/bin/sh

# Shell functions
# Author: arctelix

import platforms platform_user_home
import platforms get_platform
import config_user config_shell_prompt

DEBUG_SHELL="true"
SHELL_OUT="true"
DOTSYS_PROMPT=""

shell_debug () {
    if [ "$DEBUG_SHELL" = true ]; then
        printf "%b%b%b\n" $c_debug "$1" $rc 1>&2
    fi
}

shell_out () {
    if [ "$SHELL_OUT" = true ]; then
        printf "%b%b%b\n" "\e[0;92m" "$1" $rc 1>&2
    fi
}

# Sets global flag for shell reload when topic matches "shell" or $active_shell
flag_reload () {
    local topic="$1"
    local flagged="$2"
    local active_shell="$ACTIVE_SHELL"
    local state=1

    # Test if topic is current_shell or "required"
    if ! [ "$ACTIVE_SHELL" ] || [ "$topic" = "$active_shell" ] || [ "$topic" = "shell" ];then
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
    local script="$1"
    if [ "$ACTIVE_LOGIN_SHELL" ];then
        exec -l $ACTIVE_SHELL $script
    elif [ "$ACTIVE_SHELL" ]; then
        exec $ACTIVE_SHELL $script
    else
        exec -l $SHELL $script
    fi

    # Remove flag for reload
    export RELOAD_SHELL=""
}


# Sources all required files for shell initialization
# all login shell init files must call this function
shell_init() {
    dprint "init_shell $1 $2"
    local shell="$(get_active "$1")"
    local file="$2"
    local login="$3"

    # Abort if active or spcified shell already initialized
    if [ "$SHELL_INITIALISED" = "$shell" ];then
        echo "already initialized $shell" 1>&2
        return
    fi

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


    local home="$(platform_user_home)"
    local platform="$(get_platform)"
    local profile="$(get_file "profile" "$shell")"
    local shellrc="$(get_file "rcfile" "$shell")"

    SHELL_INITIALISED="$shell"
    ACTIVE_SHELL="$SHELL_INITIALISED"
    SHELL_FILES_LOADED+=("$file")

    shell_out "INITIALIZEING $shell $login from $file"

    # load global rc file
    [ "$file" != ".shellrc" ] && load_source_file "$home/.shellrc" "RCFILE"

    # zsh loads .zshrc on it's own after profile so skip it here
    #if ! [ "$ACTIVE_SHELL" = "zsh" ];then
        [ "$file" != "$shellrc" ] && load_source_file "$home/$shellrc" "RCFILE"
    #fi

    if [ "$login" ];then

        ACTIVE_LOGIN_SHELL="$SHELL_INITIALISED"

        # Load global .profile if it exists
        [ "$file" != ".profile" ] && load_source_file "$home/.profile" "PROFILE"

        # Load shells unique profile ie:.zsh_profile if it exists
        [ "$file" != "$profile" ] && load_source_file "$home/$profile" "PROFILE"

        shell_out "> LOADING PROFILE $file"
    else
        shell_out "> LOADING RCFILE $file"
    fi

    set_prompt
}

load_source_file(){
    local file="$1"
    local init_file="$2"
    local file_name="$(basename "$file")"
    local topic="$(basename "$(dirname "$file")")"

    if [ ! -f "$file" ]; then return;fi

    if [ "$init_file" ]; then
        shell_out "> LOADING $init_file $file_name"
    else
        shell_out "  - loading $topic/$file_name"
    fi
    source "$file"
    SHELL_FILES_LOADED+=("$file_name")
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


# Sets the dotsys prompt for the active shell
# Omit mode arg to check for user preference
# or use 'on' or 'off' to force
set_prompt () {

    local mode="$1"
    local dsprompt

    # Only use dotsys prompt if enabled by user
    if ! [ "$mode" ] && ! config_shell_prompt; then return; fi

    if [ "$ACTIVE_SHELL" = "zsh" ];then
        autoload -Uz colors && colors
        dsprompt="$fg[green]|DS|$reset_color"
    else
        dsprompt="\e[0;92m|DS|\e[0m"
    fi

    # Toggle off
    if [ "$mode" = "off" ]; then
        PS1="${PS1/$dsprompt}"
    # Toggle on
    elif [ "$PS1" = "${PS1/$dsprompt}" ]; then
        PS1="$dsprompt$PS1"
    fi
}