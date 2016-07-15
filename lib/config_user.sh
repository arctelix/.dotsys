#!/bin/bash

# User config functions
# Author: arctelix

import state get_state_value
import state set_state_value
import state in_state

# USER CONFIG

# Gets or Sets user state value
config_user_var () {
    local usage="config_user_var [value to set] [<option>]"
    local usage_full="
        -p | --prompt <text>     Prompt for user value
        -r | --ptext  <text>     Prompt text override
        -d | --default <val>     Default value for user input
        -b | --bool )            Variable is a boolean value
        -e | --edit )            Edit only mode (error if var does not exist)
    "

    local var="$1"; shift
    local set
    local ptext
    local default
    local user_input
    local val
    local ec
    local non_bool="--options omit"
    local edit_only
    local user_input_opts
    user_input_opts=()

    while [[ $# > 0 ]]; do
        case "$1" in
        -p | --prompt )   set="$1";;
        -t | --ptext )    ptext="$2"; shift ;;
        -d | --default )  default="${2#*\\}"; shift ;;
        -b | --bool )     non_bool="";;
        -e | --edit )     edit_only="$1";;
        -* | --* )        user_input_opts+=( "$1" "$2" );shift;;
        *)  if ! [ "$set" ]; then set="$1";fi;;
        esac
        shift
    done

    val="$(get_state_value "user" "$var")"
    ec=$?

    debug "-- config_user_var $var s:$set v:$val"

    if [ "$set" ];then

        # EDIT ONLY Return error if variable does not already exist
        if [ "$edit_only" ] && ! in_state "user" "$var"; then return 1; fi

        # Set from user input
        if [ "$set" = "--prompt" ]; then
            if ! [ "$ptext" ]; then
                ptext="Provide a value for $(echo "$var" | tr '_' ' ')"
            fi

            # Convert bool to yes/no
            if ! [ "$val" ] && in_state "user" "$var"; then
                if [ "$ec" -eq 0 ]; then val=yes
                elif [ "$ec" -eq 1 ]; then val=no;fi
            fi

            # Remove chars form defaults
            default="$(echo "$default" | tr -d '\r' | tr -d '\n')"

            debug "   config_user_var: prompt:$ptext d:$default bool:$non_bool"
            get_user_input "$ptext " --default "${val:-$default}" $non_bool "${user_input_opts[@]}"
            val="$user_input"

        # Set from value
        else
            debug "   config_user_var: set:$set"
            val="$set"
        fi
    fi

    # Set the value
    if [ "$set" ]; then
        # Convert to boolean value
        if [ "$val" = "yes" ]; then val=0
        elif [ "$val" = "no" ]; then val=1;fi
        set_state_value "user" "$var" "$val"
        ec=$?

    # Return exit code as required
    elif [ "$val" ] && [ "$val" != "0" ] && [ "$val" != "1" ]; then
        echo "$val"
    fi

    return $ec
}

# All user options require a function called "config_<variable name>"
# Each config function must call config_user_var and takes the following arguments:
# Getter : no arguments     Gets the value from user state
# Setter : <value>          Sets the supplied value
# Setter : --prompt         Prompts user for a value to set

config_user_name () {
    config_user_var "user_name" "$1" -d "$(cap_first "$(whoami)")"
}

config_user_email () {
    config_user_var "user_email" "$1" -d "$(get_state_value "user" "git_author_email")"
}

get_user_name () {
    config_user_name
}

config_primary_repo () {
    local val="$1"
    local user_input

    if [ "$val" = "--prompt" ]; then
        prompt_config_or_repo "set as your primary repo"
        val="$user_input"
    elif [ "$val" ];then
        validate_config_or_repo "$val"
        val="$user_input"
    fi

    config_user_var "primary_repo" "$val"
}

config_show_logo () {
    local prompt="Show the dotsys logo when working on multiple topics?
            $spacer (it's helpful)"
    config_user_var "show_logo" "$1" --bool --ptext "$prompt"
}

config_show_stats () {
    local prompt="Show the dotsys stats when working on multiple topics?
            $spacer (it's helpful)?"
    config_user_var "show_stats" "$1" --bool --ptext "$prompt"
}

config_shell_prompt () {
    local prompt="Use the dotsys shell prompt?"
    config_user_var "shell_prompt" "$1" --bool --ptext "$prompt"
}

config_shell_debug () {
    local prompt="Debug the shell loading process?"
    config_user_var "shell_debug" "$1" --bool --ptext "$prompt"
}

config_shell_output () {
    local prompt="Show sourced files on shell load?"
    config_user_var "shell_output" "$1" --bool --ptext "$prompt"
}

config_symlink_option () {
    local prompt="When installing topic dotfiles, which version do you want to use?
          $spacer repo     : Use your repo versions and backup existing originals (typical).
          $spacer original : Import existing originals and backup repo versions (new repo).
          $spacer skip     : Do not install repo version (dry run).
          $spacer confirm  : Confirm each dotfile as required."
    config_user_var "symlink_option" "$1" -d "confirm" --ptext "$prompt" \
    --options omit --extra repo --extra original --extra skip --extra confirm
}

config_symlink_norepo () {
    local prompt="When installing stub files, if exiting originals are found that
          $spacer do not exist in your repo, which version do you want to use?
          $spacer repo     : Use the stub file only (typical).
          $spacer original : Import the original file to your repo (new repo).
          $spacer skip     : Do not install repo version (dry run).
          $spacer confirm  : Confirm each dotfile as required."

    config_user_var "symlink_norepo" "$1" -d "confirm" --ptext "$prompt" \
    --options omit --extra repo --extra original --extra skip --extra confirm
}

config_unlink_option () {
    local prompt="When un-installing dotfiles, which version do you want to keep?
          $spacer repo     : Keep a copy of your repo version in use.
          $spacer original : Restore and use the original backup file. (typical)
          $spacer none     : Remove the repo version and do not restore backup.
          $spacer confirm  : Confirm each dotfile as required."
    config_user_var "unlink_option" "$1" -d "confirm" --ptext "$prompt" \
    --options omit --extra repo --extra original --extra none --extra confirm
}

config_unlink_nobackup () {
    local prompt="When un-installing dotfiles and no original backup exists,
          $spacer which version do you want to keep?
          $spacer repo     : Keep a copy of your repo version in use.
          $spacer none     : Remove the repo version (typical).
          $spacer confirm  : Confirm each dotfile as required."
    config_user_var "unlink_nobakup" "$1" -d "confirm" --ptext "$prompt" \
    --options omit --extra repo --extra original --extra none --extra confirm
}

config_use_stubs () {

    if [ "$1" = "--prompt" ]; then
          info "Stub files are at the core of dotsys, but are not required.
        $pascer They facilitate separation of your shell configuration and
        $specer help to insure that your dotfiles are usable by everyone.
        $spacer They also allow topics to collect user specific information
        $spacer and source topic related files from other topics such as
        $spacer *.shell, *.bash, *.zsh, *.vim, etc.. You should say yes!"
        local prompt="Would you like use dotsys sub files?"
    fi

    local user_input
    config_user_var "use_stub_files" "$1" --bool --ptext "$prompt"
    local ret=$?

    if [ "$1" = "--prompt" ] && [ $ret -eq 0 ]; then
        info "If you are migrating from another dotfile manager and your
      $spacer current shell config files source topic files by extension
      $spacer *.shell, *.bash, *.zsh, etc you can remove this functionality
      $spacer since dotsys takes care of it for you now. You can review stub
      $spacer files by opening the symlink in your home directory.

      $spacer IMPORTANT NOTE: Dotsys does not source *.sh files from topics!
      $spacer - shell extensions are sourced by all shells.
      $spacer - bash  extensions are sourced by bash only.
      $spacer - zsh  extensions are sourced by zsh only."
    fi

    return $ret
}

# Walk through all user config options
new_user_config () {

    print_logo

    printf "\n"

    info "Set System Configuration Values:"
    msg_help "$spacer These values can be changed at any time with the commands:\n"
    msg_help "$spacer Run this configuration again: \n$spacer> $(code "dotsys config\n")\n"
    msg_help "$spacer Set a specific config value: \n$spacer> $(code "dotsys config <var> [value, --prompt]")\n"

    printf "\n"

    task "Set Default User Variables:"

    config_user_name --prompt
    config_user_email --prompt

    printf "\n"

    task "Set System Options:"

    config_show_logo --prompt
    config_show_stats --prompt
    config_use_stubs --prompt
    config_shell_prompt --prompt
    config_shell_output --prompt

    printf "\n"

    task "Set Hands Free Options:"
    msg_help "$spacer The following options allow for hands free install and uninstall.
              $spacer NEW USERS should choose 'confirm' to evaluate each file individually."

    config_symlink_option --prompt
    config_symlink_norepo --prompt
    config_unlink_option --prompt
    config_unlink_nobackup --prompt

    printf "\n"
    msg "\nCongratulations $(get_user_name), your preferences are set!\n"
    printf "\n"
}

new_user_config_repo () {

    msg "The last step is to set a primary repo.  This will
    \rbe the default repo used when you run dotsys commands.
    \rUse the format $(code "github_user_name/repo_name")"
    printf "\n"
    msg_help "A GitHub.com account is required for syncing your
    \ryour configuration on multiple machines. If you proceed
    \rwithout a GitHub.com account you still need to choose
    \ra user name for your repo."
    printf "\n"

    config_primary_repo --prompt
}

# Test for new user
is_new_user () {
    # Empty user state file is new user
    # ! [ -s "$(state_file "user")" ]
    ! in_state "user" "primary_repo"
}
