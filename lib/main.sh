#!/bin/sh

# Main entry point and command handler

# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

#TODO: handle .stub files for symlinks
#TODO: handle .settings files

#TODO: TEST new repo branch syntax = "action user/repo:branch" or "action repo branch"

#TODO: FOR NEW Installs prompt for --force & --confirm options
#TODO: Finish implementing success_or_ functions....

#TODO QUESTION: Change freeze to show.. as in show status.  ie dotsys show brew, show git, show tmux
#TODO QUESTION: Symlink "all" choice should apply to all topics? (currently just for topic)
#TODO QUESTION: Hold package_manager packages install to end of topic run

#TODO ROADMAP:  Detect platforms like babun and mysys as separate configs, and allow user to specify system.

# Fail on errors.
# set -e

# Show executed commands
#set -x

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

#GLOBALS
STATE_SYSTEM_KEYS="installed_repo user_repo show_logo show_stats"

DEFAULT_APP_MANAGER=
DEFAULT_CMD_MANAGER=

# current active repo (set by load_config_vars)
ACTIVE_REPO=
ACTIVE_REPO_DIR=

# user info (set by set_user_vars)
PRIMARY_REPO=
USER_NAME=
REPO_NAME=

# persist state for topic actions & symlinks
GLOBAL_CONFIRMED=

# persist state for topic actions only
TOPIC_CONFIRMED=

# text message for dry runs
DRY_RUN=

#track mangers actively used by topics or packages
ACTIVE_MANAGERS=()

#track uninstalled topics (populated but not used)
UNINSTALLED_TOPICS=()

#track installed topics (populated but not used)
INSTALLED=()

# path to user bin
USER_BIN="/usr/local/bin"

# Current platform
PLATFORM="$(get_platform)"

#path to debug file
DEBUG_FILE="$DOTSYS_REPOSITORY/debug.log"

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
    -r | repo [branch]      Limit action to primary repo management (not topics)
    <user/repo[:branch]>    Same as 'repo' for specified repo
    -l | links              Limit action to symlinks
    -m | managers           Limit action to package managers
    -p | packages           Limit action to package manager's packages
    -s | scripts            Limit action to scripts
    -f | from <user/repo>   Apply action to topics from specified repo

    <options> optional: use to bypass confirmations.
    --force             force action even if already completed
    --dryrun)           runs through all tasks, but not changes are actually made (must confirm each task)
    --confirm           bypass topic confirmation and backup / restore backup for existing symlinks
    --confirm delete    bypass topic confirmation and delete existing symlinks on install & uninstall
    --confirm backup    bypass topic confirmation and backup existing symlinks on install & restore backups on uninstall
    --confirm dryrun    Same as dryrun option but bypasses confirmations


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


    bins:               topic/bin/file_name.sh
                        symlinked to dotsys/bin which is in path

    managers:           Manages packages of some type, such as brew, pip, npm, etc...
                        A topic/manager.sh script designates a manager topic and defines
                        a function for each required action (install, uninstall, freeze, upgrade).

    configs:            topic/.dotsys.cfg
                        topic level config file

    stubs:              topic/file.stub
                        Stubs allow topics to add functionality to each other.
                        For example: The stub for .vimrc is linked to the home
                        directory where vim can read it.  The stub will then source
                        the vim/vimrc.stub and search for topic/*.vimrc files.
                        Provide vim/vimrc.symlink to not use stubs for that topic.


    scripts:            scripts are optional and placed in each topic root directory

      topic.sh          A single script containing functions for each required action
                        see action function definitions

    action functions:   The rules below are important (please follow them strictly)

      install:          Makes permanent changes that only require running on initial install (run once)!
      uninstall         Must undo everything done by install (run once)!
      upgrade           Only use for changes that bump the installed component version!
                        Topics with a manager typically wont need this, the manager will handle it.
      update:           Only use to update dotsys with local changes or data (DO NOT BUMP VERSIONS)!
                        ex: reload a config file so local changes are available in the current session
                        ex: refresh data from a webservice
      freeze:           Output the current state of the topic
                        ex: A manager would list installed topics
                        ex: git will show the current status

    scripts (depreciated and replaced by topic.sh action functions)

      install.sh        see action function definitions
      uninstall.sh      see action function definitions
      upgrade.sh        see action function definitions
      update.sh         see action function definitions
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
    local from_branch=
    # allow toggle on a per run basis
    # also used internally to limit to one showing
    # use user_toggle_logo to turn logo off permanently
    local show_logo=0
    local show_stats=0

    while [[ $# > 0 ]]; do
    case $1 in
        # limits
        -d | dotsys )   limits+=("dotsys") ;;
        -r | repo)      limits+=("repo")    #no topics permitted (just branch)
                        if [ "$2" ]; then from_branch="$2";shift ;fi ;;
        -l | links)     limits+=("links") ;;
        -m | managers)  limits+=("managers") ;;
        -p | packages)  limits+=("packages") ;;
        -s | scripts)   limits+=("scripts") ;;
        -f | from)      from_repo="$2"; shift ;;

        # options
        --tlogo)        show_logo=$(! $(get_state_value "show_logo")) ;;
        --tstats)       show_stats=$(! $(get_state_value "show_stats")) ;;
        --force)        force="--force" ;;
        --recursive)    recursive="true" ;; # used internally for recursive calls
        --dryrun)       DRY_RUN="(dry run) " ;;
        --confirm)      if [[ "$2" =~ (delete|backup|skip) ]]; then
                            GLOBAL_CONFIRMED="$2"
                            if [ "$2" = "dryrun" ]; then
                                DRY_RUN="(dry run) "
                                GLOBAL_CONFIRMED="skip"
                            fi
                            shift
                        # default val for confirm
                        else
                            GLOBAL_CONFIRMED="backup"
                        fi ;;
        --*)            invalid_option ;;
        -*)             invalid_limit ;;
        *)              topics+=("$1") ;;
    esac
    shift
    done

    required_vars "action"

    TOPIC_CONFIRMED="${TOPIC_CONFIRMED:-$GLOBAL_CONFIRMED}"

    debug "[ START DOTSYS ]-> a:$action t:${topics[@]} l:$limits force:$force conf:$GLOBAL_CONFIRMED r:$recursive from:$from_repo"

    # Set persistent options
    if [ "$DRY_RUN" ]; then
        GLOBAL_CONFIRMED="skip"
    fi

    # ALLOW direct manager package manipulation
    # This allows dotsys to manage packages without a topic directory
    # for example: 'dotsys install <manager> packages <packages>'   # specified packages
    # for example: 'dotsys install <manager> packages file'         # all packages in package file
    # for example: 'dotsys install <manager> packages'              # all installed packages
    # todo: Considering api format 'dotsys <manager> install <package>'
    if in_limits "packages" -r && is_manager "${topics[0]}" && [ ${#topics[@]} -gt 1 ] ; then
      local manager="${topics[0]}"
      local i=0 # just to make my syntax checker not fail (weird)
      unset topics[$i]
      debug "main -> ONLY $action $manager ${limits[@]} ${topics[@]} $force"
      manage_packages "$action" "$manager" ${topics[@]} "$force"
      return
    fi

    # HANDLE REPO LIMIT

    # First topic "repo" or "xx/xx" = limits "repo"
    if topic_is_repo; then
        debug "main -> topic is repo: ${topics[0]}"
        limits+=("repo")
        from_repo="${topics[0]}"
        topics=
    elif in_limits "repo" -r; then
        debug "main -> repo is in limits"
        from_repo="repo"
        topics=
    fi

    # allow "repo" as shortcut to active repo
    if [ "$from_repo" = "repo" ] ; then
        from_repo="$(get_active_repo)"
        if ! [ "$from_repo" ]; then
            error "There is no primary repo configured, so
            $spacer a repo must be explicitly specified"
            exit
        fi

    fi

    # LOAD CONFIG VARS Parses from_repo, Loads config file, manages repo
    if ! [ "$recursive" ]; then
        debug "main -> load config vars"
        if [ "$from_branch" ]; then
            debug "   got from_branch: $from_branch"
            from_repo="${from_repo}:$from_branch"
            debug "   new from_repo = $from_repo"
        fi
        load_config_vars "$from_repo" "$action"
    fi

    # FREEZE installed topics or create config yaml
    if [ "$action" = "freeze" ] && in_limits "dotsys"; then
        debug "main -> freeze_mode: $freeze_mode"
        if in_limits -r "repo"; then
            create_config_yaml "$ACTIVE_REPO" "${limits[@]}"
            return
        else
            freeze "$ACTIVE_REPO" "${limits[@]}"
        fi
    fi

    # END REPO LIMIT if repo in limits dotsys has ended
    if in_limits -r "repo"; then
        return
    fi


    # get all topics if not specified
    if ! [ "$topics" ]; then

        if ! [ "$ACTIVE_REPO_DIR" ]; then
            error "Could not resolve active repo directory: $ACTIVE_REPO_DIR"
            msg "$( printf "Run %bdotsys install%b to configure a repo%s" $green $yellow "\n")"
            return 1
        fi
        local list="$(get_topic_list "$ACTIVE_REPO_DIR" "$force")"
        if ! [ "$list" ]; then
            if [ "$action" = "install" ]; then
                msg "$( printf "\nThere are no topics in %b$ACTIVE_REPO_DIR%b" $green $yellow)"
            else
                msg "$( printf "\nThere are no topics %binstalled by dotsys%b to $action" $green $yellow)"
            fi
        fi
        topics=("$list")
        debug "main -> topics list:\n\r$topics"
        debug "main -> end list"
    fi

    # Iterate topics

    debug "main -> TOPIC LOOP START"

    local topic

    for topic in ${topics[@]};do

        # ABORT: NON EXISTANT TOPICS
        if ! topic_exists "$topic"; then
            # error message supplied by topic_exits
            continue
        fi

        # LOAD TOPIC CONFIG (must be first and not in $(subshell) !)
        load_topic_config_vars "$topic"

        # ABORT: on platform exclude
        if platform_excluded "$topic"; then
            task "$(printf "Excluded %b${topic}%b on $PLATFORM" $green $blue)"
            continue
        fi

        # TOPIC MANGERS HAVE SPECIAL CONSIDERATIONS
        if is_manager "$topic"; then
            debug "main -> Handling manager: $topic"

            # All actions but uninstall
            if ! [ "$action" = "uninstall" ]; then
                debug "main -> ACTIVE_MANAGERS: ${ACTIVE_MANAGERS[@]}"
                # ABORT: Silently prevent managers from running more then once (even with --force)
                if [[ "${ACTIVE_MANAGERS[@]}" =~ "$topic" ]]; then
                    debug "main -> ABORT MANGER ACTION: Already ${action#e}ed $topic"
                    continue
                fi
                # create the state file
                touch "$(state_file "$topic")"
                # set active (prevents running manager tasks more then once)
                ACTIVE_MANAGERS+=("$topic")

            # uninstall is a bit different
            else

                # on uninstall we need to remove packages from package file first (or it will always be in use)
                if manager_in_use && in_limits "packages"; then
                    # TODO: URGENT all associated packages including topics are uninstalled
                    # the change get_package_list may not be wise, upgrade, freeze, run twice
                    # uninstall should be fine now since the topics are removed from state
                    # RETHINK package list results! probable stupid since manager_in_use already checks state
                    # no need for manage_packages to do it to, that will solve the problem!!!!!
                    # this may not be desirable, work though scenarios for best behavior
                    debug "main -> UNINSTALL MANAGER PACKAGES FIRST: $topic"
                    manage_packages "$action" "$topic" file "$force"
                fi

                # ABORT: uninstall if it's still in use (uninstalled at end as required).
                if manager_in_use "$topic"; then
                    warn "$(printf "Manager %b$topic%b is in use and can not be uninstalled yet." $green $rc)"
                    ACTIVE_MANAGERS+=("$topic")
                    debug "main -> ABORT MANGER IN USE: Active manager $topic can not be ${action%e}ed."
                    continue
                # now we can remove the sate file
                else
                    local sf="$(state_file "$topic")"
                    if [ -f "$sf" ]; then
                        debug "********* REMOVE STATE FILE $sf"
                        rm "$sf"
                    fi
                    # remove from active managers
                    ACTIVE_MANAGERS=( "${ACTIVE_MANAGERS[@]/$topic}" )
                fi
            fi

        # ABORT: Non manager topics when limited to managers
        else
            debug "main -> Handling topic: $topic"
            if in_limits "managers" -r; then
                debug "main -> ABORT: manager in limits and $topic is not a manger"
                continue
            fi
        fi


        # ABORT: on install if already installed (override --force)
        if [ "$action" = "install" ] && is_installed "dotsys" "$topic" && [ ! "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        # ABORT: on uninstall if not installed (override --force)
        elif [ "$action" = "uninstall" ] && ! is_installed "dotsys" "$topic" && [ ! "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        fi

        # CONFIRM TOPIC
        debug "main -> call confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"
        confirm_task "$action" "$topic" "${limits[@]}"
        if ! [ $? -eq 0 ]; then continue; fi
        debug "main -> post confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"


        # ALL CHECKS DONE START THE ACTION

        # 1) dependencies
        if [ "$action" = "install" ] && in_limits "scripts" "dotsys"; then
            install_dependencies "$topic"
        fi

        # 2) managed topics
        local topic_manager="$(get_topic_manager "$topic")"
        if [ "$topic_manager" ]; then

            # make sure the topic manager is installed on system
            if [ "$action" = "install" ] && ! is_installed "dotsys" "$topic_manager"; then
                info "$(printf "${action}ing manager %b$topic_manager%b for %b$topic%b" $green $rc $green $rc)"
                # install the manager
                dotsys "$action" "$topic_manager" ${limits[@]} --recursive
            fi

            # Always let manager manage topic
            debug "main -> END RECURSION calling run_manager_task: $topic_manager $action t:$topic $force"
            run_manager_task "$topic_manager" "$action" "$topic" "$force"
        fi

        # 3) symlinks
        if in_limits "links" "dotsys"; then
            debug "main -> call symlink_topic: $action $topic confirmed? gc:$GLOBAL_CONFIRMED tc:$TOPIC_CONFIRMED"
            symlink_topic "$action" "$topic"
        fi

        # 4) scripts
        if in_limits "scripts" "dotsys"; then
            debug "main -> call run_topic_script"
            run_topic_script "$action" "$topic"
        fi

        # 5) packages
        if [ "$action" != "uninstall" ] && is_manager && in_limits "packages"; then
            debug "main -> call manage_packages"
            manage_packages "$action" "$topic" file "$force"
        fi

        # track uninstalled topics
        if [ "$action" = "uninstall" ]; then
           UNINSTALLED_TOPICS+=(topic)
        fi
    done

    debug "main -> TOPIC LOOP END"

    # Finally check for repos and managers that still need to be uninstalled
    if [ "$action" = "uninstall" ]; then

        # Check for inactive managers to uninstall
        if in_limits "managers"; then
            debug "main -> clean inactive managers"
            local inactive_managers=()
            local m
            debug "main -> active_mangers: ${ACTIVE_MANAGERS[@]}"
            debug "main -> topics: ${topics[@]}"

            for m in ${ACTIVE_MANAGERS[@]}; do
                [[ "${topics[@]}" =~ "$m" ]]
                debug "main -> test for $m in topics = $?"
                if ! manager_in_use "$m" && [[ "${topics[@]}" =~ "$m" ]]; then
                    debug "main -> ADDING INACTIVE MANAGER $m"
                    inactive_managers+=("$m");
                fi
            done
            debug "main -> INACTIVE MANGERS: ${inactive_managers[@]}"
            if [ "${inactive_managers[@]}" ]; then
                debug "main -> uninstall inactive managers: $inactive_managers"
                dotsys uninstall ${inactive_managers[@]} ${limits[@]} --recursive
                return
            fi
        fi

        # Check if all repo topics are uninstalled & uninstall
        if in_limits "repo" && ! repo_in_use "$ACTIVE_REPO"; then
            debug "main -> REPO NO LONGER USED uninstalling"
            manage_repo "uninstall" "$ACTIVE_REPO" "$force"
        fi
    fi

    debug "main -> FINISHEÍD"
}


dotsys_installer () {

    local usage="dotsys_installer <action>"
    local usage_full="Installs and uninstalls dotsys.
    1) Put
    -i | install        install dotsys
    -x | uninstall      install dotsys
    "

    local action=
    case "$1" in
    -i | install )    action="$1" ;;
    -x | uninstall )  action="$1" ;;
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




