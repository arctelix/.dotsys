#!/bin/sh

# Main entry point and command handler

# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

#TODO: Handle symlink config for alternate locations
#TODO: Finish install script

# Fail on errors.
# set -e

# Show executed commands
# set -x

if ! [ "$DOTSYS_LIBRARY" ];then
    if [ ! -f "$0" ];then
        DOTSYS_REPOSITORY="$(dirname "$BASH_SOURCE")"
    else
        DOTSYS_REPOSITORY="$(dirname "$0")"
    fi
    DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"
fi

echo "main DOTSYS_LIBRARY: $DOTSYS_LIBRARY"

. "$DOTSYS_LIBRARY/common.sh"
. "$DOTSYS_LIBRARY/yaml.sh"
. "$DOTSYS_LIBRARY/screenio.sh"
. "$DOTSYS_LIBRARY/state.sh"
. "$DOTSYS_LIBRARY/iterators.sh"
. "$DOTSYS_LIBRARY/platforms.sh"
. "$DOTSYS_LIBRARY/scripts.sh"
. "$DOTSYS_LIBRARY/managers.sh"
. "$DOTSYS_LIBRARY/symlinks.sh"
. "$DOTSYS_LIBRARY/config.sh"
. "$DOTSYS_LIBRARY/repos.sh"

# GLOBALS

DEFAULT_APP_MANAGER=
DEFAULT_CMD_MANAGER=

# Not required since state ?
INSTALLED=()

# current active repo
ACTIVE_REPO_DIR=

# Set by set_user_vars
PRIMARY_REPO=
USER_NAME=
REPO_NAME=

USER_BIN="/usr/local/bin"

# REQUIRED PLATFORM SETUP
PLATFORM="$(get_platform)"

#log "DOTFILES_ROOT: $(dotfiles_dir)"

dotsys () {
    local usage="manage_topic <action> [<topics or repo>] [<limits>] [<options>]"
    local usage_full="
    <action> required:  Primary action to take on one or moore topics.

    -i | install       runs install scripts, downloads repos,  and installs package_manager packages
    -x | uninstall     runs uninstall scripts deletes repos, and uninstalls package_manager packages
    -u | upgrade       runs upgrade scripts, upgrades package_manager packages, and
                       syncs dotsys repos (bumps package versions)
    -r | reload        runs reload scripts, re-sources bin, re-sources stub files
                       (does not bump package versions)
    -f | freeze        creates config file of current state


    <topics or repo> optional:

    omitted            Omit topic names to apply action to all available topics
    topic              Limits action to specified topics (space separated list)
    repo               Applies to specified repo (user/repo_name)

    <limits> optional:
    -d | dotsys        Limit action to dotsys
    -l | links         Limit action to links
    -m | managers      Limit action to managers
    -s | scripts       Limit action to scripts


    <options> optional:  may come before or after topic list.

    -c | --confirm     <action, delete, backup, restore, skip>
                       action: pre-confirm topic action only
                       delete: pre-confirm topic and delete symlink conflicts on install / delete on uninstall
                       backup: pre-confirm topic and backup symlink conflicts on install / restore backups on uninstall
                       skip: pre-confirm topic action and skip symlinks


    Limit to dotsys:
    The 'dotsys' limit excludes package manager functions.

    install       symlinks .dotsys directory, runs all topic/install.sh, downloads repos,
                  but managers packages are not installed (run to bypass package managers)
    uninstall     removes .dotsys directory, runs all topic/uninstall.sh, , deletes repos,
                  but managers packages are not uninstalled (run to bypass package managers)
    upgrade       git pushes or git pulls all repos as required, runs all topic/upgrade.sh,
                  bypass manager fucntions (run to sync your repo changes)
    reload        re-sources bins and stubs, runs all topic/reload.sh,
                  bypass manager.reload functions (run to test topic modifications)
    freeze        creates config file reflecting current state, excluding managed packages

    Example usage:

    - Install all topics
      $ dotsys install
    - Uninstall one or more topics
      $ dotsys uninstall vim tmux
    - Upgrade one or more topics and bypass confirmation (symlinks will need to be confirmed)
      $ dotsys upgrade brew dotsys --confirm action
    - Upgrade one or more topics and bypass confirmation (symlinks will need to be confirmed)
      $ dotsys upgrade brew dotsys --confirm action

    Organization:

    Each topic consists of symlinks, scripts, managers, stubs, bins, configs.

    symlinks:           topic/file_name.symlink
                        Symlinked to home or specified directory

    scripts:            topic/script.sh
                        install.sh, uninstall.sh, upgrade.sh, reload.sh

    bin:                topic/bin/file_name.sh
                        symlinked to dotsys/bin which is in path

    manager:            topic/manager.sh
                        designates a manager topic and defines manager functions

    config              topic/.dotsys.cfg
                        topic level config file

    stub                topic/file.stub
                        Stubs allow topics to add functionality to each other.
                        For example: The stub for .vimrc is linked to the home
                        directory where vim can read it.  The stub will then source
                        the vim/vimrc.stub and search for topic/*.vimrc files.
                        Provide vim/vimrc.symlink to not use stubs for that topic.


    SCRIPTS:            scripts are optional and placed in each topic root directory
      install.sh:       Should only need to be run once, on install!
      uninstall.sh:     Should only need to be run once, on uninstall!
      upgrade.sh:       Only use for changes that bump the version.
      reload.sh:        Only use to reload local changes without a version bump.
    "

    check_for_help "$1"

    local action=
    local freeze_mode=

    case $1 in
      -i | install )    action="install" ;;
      -x | uninstall)   action="uninstall" ;;
      -u | upgrade )    action="upgrade" ;;
      -r | reload )     action="reload" ;;
      -l | freeze)      action="freeze"
           if [[ "$FREEZE_MODES" =~ "$2" ]]; then freeze_mode="$2";shift;fi ;;
      -e | export)      action="export" ;;
      * )  error "'$1' is not a valid action%b"
           show_usage ;;
    esac
    shift

    local topics=()
    local limits=()
    local force=
    local from_repo=

    while [[ $# > 0 ]]; do
    case $1 in
      # limits
      -d | dotsys )     limits+=("dotsys") ;;
      -l | links)       limits+=("links") ;;
      -m | managers)    limits+=("managers") ;;
      -s | scripts)     limits+=("scripts") ;;
      -f | from)        from_repo="$2"; shift ;;

      # options
      --confirm)        P_STATE="${2:-action}"; shift ;;
      --force)          force="--force";;
      * )               topics+=("$1") ;;
    esac
    shift
    done

    log "main fm: $freeze_mode"

    required_vars "action"

    print_logo

    local P_STATE=
    local SYMLINK_STATE=


    #log "dotsys main: a:$action t:${topics[@]} l:$limits"

    # Repo as topic and not freeze.
    if topic_is_repo && [ "$action" != "freeze" ]; then
       manage_repo "$action" "${topics[0]}"
       return
    fi

    # FREEZE List installed topics or create config yaml
    if [ "$action" = "freeze" ] && in_limits "dotsys"; then
        if topic_is_repo; then
            create_config_yaml "${topics[0]}" "${limits[@]}"
        else
            freeze "${limits[@]}"
        fi
        return
    fi

    # Parses from_repo, Loads config file, and sets main repo
    load_config_vars "$from_repo" "$action"

    # get all topics if not specified
    if ! [ "$topics" ]; then

        if ! [ "$ACTIVE_REPO_DIR" ]; then
            error "Could not resolve repo directory"
            return 1
        fi
        local list="$(get_topic_list "$ACTIVE_REPO_DIR")"
        if ! [ "$list" ]; then
            msg "$( printf "\nThere are no topics in %b$ACTIVE_REPO_DIR%b" $green $rc)"
            msg_help "$( printf "Use %bdotsys add%b or manually create topic folders" $blue $dark_gray)"
        fi
        topics=("$list")
    fi

    # Show stats
    if [ ${#topics[@]} -gt 1 ]; then
        info "There are ${#topics[@]} topics to $action"
    fi

    # Iterate topics
    for topic in ${topics[@]};do

        # Load topic config (must be first and not in $(subshell) !)
        load_topic_config_vars "$topic"

        # Abort non existent topics
        if ! topic_exists "$topic"; then
            continue
        fi

        # Abort on platform exclude
        if platform_excluded "$topic"; then
            success "$(printf "The topic %b${topic}%b has been excluded for %b${PLATFORM}%b" $light_green $rc $light_green $rc)"
            continue
        fi

        # Abort on install if already installed (override --force)
        if [ "$action" = "install" ] && is_installed "$topic" && [ ! "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $light_green $rc)"
           continue
        fi

        confirm_task "$action" "$topic" "${limits[@]}"
        if ! [ $? -eq 0 ]; then continue; fi

        # CHECKS DONE START THE ACTION

        # 1) install dependencies (on install action only)
        if [ "$action" = "install" ] && in_limits "scripts" "dotsys"; then
            install_dependencies "$topic"
        fi

        # 2) check if topic is managed and run the manager action
        local topic_manager="$(get_topic_manager "$topic")"
        if [ "$topic_manager" ] && in_limits "managers"; then
            # make sure manager is installed on system
            if ! is_installed "$topic_manager"; then
                info "Installing manager '$topic_manager' for $topics"
                # install the manager
                dotsys "install" "$topic_manager" ${limits[@]}
            fi
            run_manager_task "$topic_manager" "$action" "$topic" "$force"
        fi

        # 3) symlink topic
        if in_limits "links" "dotsys"; then
            log "$action $topic --confirm $confirmed"
            symlink_topic "$action" "$topic" --confirm "$confirmed"
        fi

        # 4) run the appropriate topic script
        if in_limits "scripts" "dotsys"; then
            run_topic_script "$action" "$topic"
        fi

        # 5) If topic IS a manager, let it manage it's packages
        if in_limits "managers"; then
            manage_packages "$action" "$topic"
        fi
    done

    # make sure repo is installed updated
    if [ "$action" = "uninstall" ]; then
        manage_repo "$action" "$from_src"
    fi
}


in_limits () {
    local limits="${1:-$limits}"
    if ! [ "$limits" ]; then return 0;fi
    local found=1
    for l in $@; do
        if [[ ${limits[@]} =~ "$l" ]]; then
          found=0
        fi
    done
    return $found
}

topic_is_repo () {
    [[ "${topics[0]}" == *"/"* ]]
}



dotsys_installer () {

    local usage="dotsys_installer <action>"
    local usage_full="Installs and uninstalls dotsys"

    local action=
    case "$1" in
    -i | install )    action="$1" ;;
    -x | uninstall )  action="$1" ;;
    -u | upgrade )    action="$1" ;;
    -r | update )     action="$1" ;;
    * )  error "Not a valid action: $1"
         show_usage ;;
    esac

    local user_dotfiles="$(dotfiles_dir)"

    log "$action dotsys DOTSYS_REPOSITORY: $DOTSYS_REPOSITORY"
    log "$action dotsys user_dotfiles: $user_dotfiles"

    # make sure user bin is on path (TODO: need to permanently add to path)
    if [ "${PATH#*$USER_BIN}" == "$PATH" ]; then
        log "adding /usr/local/bin to path"
        export PATH=$PATH:/usr/local/bin
    fi

    # create / remove user .dotfiles directory
    if [ "$action" = "install" ]; then
        mkdir -p "$user_dotfiles"
    elif [ "$action" = "uninstall" ]; then
        rm -rf "$user_dotfiles"
    fi

    # Add dotsys to path temporarily
    #export PATH=$PATH:$ds_bin

    symlink_topic "$action" dotsys
}




