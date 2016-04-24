#!/bin/sh

# Main entry point and command handler

# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

#TODO: handle alternate symlink destinations
#TODO: handle stub files for symlinks
#TODO: handle .settings files
#TODO: on new install prompt for --force & --confirm options

#TODO ROADMAP: Handle symlink config for alternate locations
#TODO ROADMAP:  Detect platforms like babun and mysys as separate configs, and allow user to specify system.

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

#echo "main DOTSYS_LIBRARY: $DOTSYS_LIBRARY"

. "$DOTSYS_LIBRARY/common.sh"
. "$DOTSYS_LIBRARY/yaml.sh"
. "$DOTSYS_LIBRARY/terminalio.sh"
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

# current active repo (set by load_config_vars)
ACTIVE_REPO=
ACTIVE_REPO_DIR=

# user info (set by set_user_vars)
PRIMARY_REPO=
USER_NAME=
REPO_NAME=

# persist confirm state
GLOBAL_CONFIRMED=
DRY_RUN=

USER_BIN="/usr/local/bin"

PLATFORM="$(get_platform)"

#debug "DOTFILES_ROOT: $(dotfiles_dir)"

dotsys () {
    local usage="dotsys <action> [<topics> <limits> <options>]"
    local usage_full="
    <action> required:  Primary action to take on one or more topics.

    install         runs install scripts, downloads repos,
                    and installs package_manager packages
    uninstall       runs uninstall scripts deletes repos,
                    and uninstalls package_manager packages
    upgrade         runs upgrade scripts, upgrades packages,
                    and sync remote repos
    update          runs update scripts, update package managers
                    re-sources bin, re-sources stubs
    freeze [<mode>] creates config file of current state, takes optional mode <default,user,topic,full>

    <topics> optional:

    Limits action to specified topics (space separated list)
    Omit topic for all all available topics

    <limits> optional:

    -d | dotsys             Limit action to dotsys (excludes package management)
    -r | repo               Limit action to primary repo management
    <user/repo>             Same as 'repo' for specified repo
    -l | links              Limit action to symlinks
    -m | managers           Limit action to package managers
    -p | packages           Limit action to package manager's packages
    -s | scripts            Limit action to scripts
    -f | from <user/repo>   Apply action to topics from specified repo

    <options> optional: use to bypass confirmations.
    --force             force action even if already completed
    --confirm           bypass topic confirmation and backup / restore backup for existing symlinks
    --confirm delete    bypass topic confirmation and delete existing symlinks on install & uninstall
    --confirm backup    bypass topic confirmation and backup existing symlinks on install & restore backups on uninstall
    --confirm skip      runs through all tasks, but not changes are actually made. (dry run)


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
                        install.sh, uninstall.sh, upgrade.sh, update.sh

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
      update.sh:        Only use to update local changes without a version bump.
    "

    check_for_help "$1"

    local action=
    local freeze_mode=

    case $1 in
        install )   action="install" ;;
        uninstall)  action="uninstall" ;;
        upgrade )   action="upgrade" ;;
        update )    action="update" ;;
        freeze)     action="freeze"
                    if [[ "$FREEZE_MODES" =~ "$2" ]];then
                        freeze_mode="$2"
                        shift
                    fi ;;
        * )  error "Invalid action: $1 %b"
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
        -d | dotsys )   limits+=("dotsys") ;;
        -r | repo)      limits+=("repo") ;; #no additional topics permitted
        -l | links)     limits+=("links") ;;
        -m | managers)  limits+=("managers") ;;
        -p | packages)  limits+=("packages") ;;
        -s | scripts)   limits+=("scripts") ;;
        -f | from)      from_repo="$2"; shift ;;

        # options
        --force)        force="--force";;
        --confirm)      if [[ "$2" =~ (delete|backup|skip) ]]; then
                            GLOBAL_CONFIRMED="$2"
                            if [ "$2" = "skip" ]; then
                                DRY_RUN="(dry run) "
                            fi
                            shift
                        else
                            GLOBAL_CONFIRMED="backup"
                        fi ;;
        -*)  invalid_option ;;
        *)  topics+=("$1") ;;
    esac
    shift
    done

    required_vars "action"

    print_debugo

    debug "dotsys main: a:$action t:${topics[@]} l:$limits conf:$GLOBAL_CONFIRMED force:$force"

    # Set persistent options
    if [ "$DRY_RUN" ]; then
        GLOBAL_CONFIRMED="skip"
    fi

    # Set repo as first topic = limits "repo"
    if topic_is_repo; then
        debug "topic is repo: ${topics[0]}"
        limits+=("repo")
        from_repo="${topics[0]}"
        topics=
    elif in_limits "repo" -r; then
        debug "repo is in limits"
        from_repo="repo"
        topics=
    fi

    # allow from "repo" as shortcut to active repo
    if [ "$from_repo" = "repo" ] ; then
        from_repo="$(get_active_repo)"
    fi

    #TODO: need to separate repo management
    # Parses from_repo, Loads config file, manages repo, and sets main repo
    load_config_vars "$from_repo" "$action"

    # FREEZE installed topics or create config yaml
    if [ "$action" = "freeze" ] && in_limits "dotsys"; then
        debug "main freeze_mode: $freeze_mode"
        if in_limits -r "repo"; then
            create_config_yaml "from_repo" "${limits[@]}"
            return
        else
            freeze "from_repo" "${limits[@]}"
        fi
    fi

    # repo management only when "repo in limits"
    if in_limits -r "repo"; then
        return
    fi

    # get all topics if not specified
    if ! [ "$topics" ]; then

        if ! [ "$ACTIVE_REPO_DIR" ]; then
            error "Could not resolve active repo directory: $ACTIVE_REPO_DIR"
            return 1
        fi
        local list="$(get_topic_list "$ACTIVE_REPO_DIR")"
        if ! [ "$list" ]; then
            msg "$( printf "\nThere are no topics in %b$ACTIVE_REPO_DIR%b" $green $rc)"
            msg_help "$( printf "Use %bdotsys add%b or manually create topic folders" $blue $dark_gray)"
        fi
        topics=("$list")
        debug "topics list: $topics"
    fi

    # Show stats
    if [ ${#topics[@]} -gt 1 ]; then
        info "There are ${#topics[@]} topics to $action"
    fi

    # Iterate topics
    for topic in ${topics[@]};do

        local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"

        # Load topic config (must be first and not in $(subshell) !)
        load_topic_config_vars "$topic"

        # ABORT: non existent topics
        if ! topic_exists "$topic"; then
            # message supplied by topic_exits
            continue
        fi

        # ABORT: on platform exclude
        if platform_excluded "$topic"; then
            task "$(printf "Excluded %b${topic}%b on $PLATFORM" $green $blue)"
            continue
        fi

        # ABORT: on install if already installed (override --force)
        if [ "$action" = "install" ] && is_installed "dotsys" "$topic" && [ ! "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        fi

        # ABORT: on uninstall if not installed (override --force)
        if [ "$action" = "uninstall" ] && ! is_installed "dotsys" "$topic" && [ ! "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        fi

        debug "main pre confirm_task: $GLOBAL_CONFIRMED / $TOPIC_CONFIRMED"
        # CONFIRM topic
        confirm_task "$action" "$topic" "${limits[@]}"
        if ! [ $? -eq 0 ]; then continue; fi
        debug "main post confirm_task: $GLOBAL_CONFIRMED / $TOPIC_CONFIRMED"


        # CHECKS DONE START THE ACTION

        # 1) install dependencies (on install action only)
        if [ "$action" = "install" ] && in_limits "scripts" "dotsys"; then
            install_dependencies "$topic"
        fi

        # 2) Managed topics need to be managed before scripts are run
        local topic_manager="$(get_topic_manager "$topic")"
        if [ "$topic_manager" ] && in_limits "managers"; then
            # make sure the topic manager is installed on system
            if ! is_installed "dotsys" "$topic_manager"; then
                info "Installing manager '$topic_manager' for $topics"
                # install the manager
                dotsys "install" "$topic_manager" ${limits[@]}
            fi
            debug "main calling run_manager_task: m:$topic_manager a:$action t:$topic f:$force"
            run_manager_task "$topic_manager" "$action" "$topic" "$force"
        fi

        # 3) symlink topic
        if in_limits "links" "dotsys"; then
            debug "main call symlink: $action $topic confirmed: $GLOBAL_CONFIRMED / $TOPIC_CONFIRMED"
            symlink_topic "$action" "$topic"
        fi

        # 4) run the appropriate topic script
        if in_limits "scripts" "dotsys"; then
            run_topic_script "$action" "$topic"
        fi

        # 5) Check if topic IS a manager and manage it's packages
        if in_limits "packages"; then
            manage_packages "$action" "$topic" "$force"
        fi
    done

    # will only uninstall if not repo_in_use
    manage_repo "uninstall" "$from_repo" "$force"

}


in_limits () {
    local option=
    local search=$@
    local found=1
    search=
    while [[ $# > 0 ]]; do
        case $1 in
        -r | --required)  option="required";;
        * )   search+="$1 "      ;;
        esac
        shift
    done

    if [ "$option" != "required" ] && ! [ "$limits" ]; then
        return 0
    fi

    local s
    for s in $search; do
        if [[ ${limits[@]} =~ "$s" ]]; then
            return 0
        fi
    done
    return $found
}

topic_is_repo () {
    [ "${topics[0]}" = "repo" ] && topics[0]="$(get_active_repo)" || [[ "${topics[0]}" == *"/"* ]]
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

    #TODO: make sure all required dirs and files not in git exist (ie state, user) then remove checks for files and dirs

    local user_dotfiles="$(dotfiles_dir)"

    debug "$action dotsys DOTSYS_REPOSITORY: $DOTSYS_REPOSITORY"
    debug "$action dotsys user_dotfiles: $user_dotfiles"

    # make sure user bin is on path (TODO: need to permanently add to path)
    if [ "${PATH#*$USER_BIN}" == "$PATH" ]; then
        debug "adding /usr/local/bin to path"
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




