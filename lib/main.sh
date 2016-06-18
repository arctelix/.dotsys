#!/bin/sh

# Main entry point and command handler
#
# Author: Arctelix (http://gitbub.com/arctelix)
# Licence: GNU General Public License
#
# With thanks to the following sources:
# https://github.com/holman/dotfiles
# https://github.com/agross/dotfiles
#
# Dotsys - A platform agnostic package-manager with dotfile integration
#
# Copyright (C) 2016  Arctelix (http://gitbub.com/arctelix)
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# Other useful reference & rationale
# http://superuser.com/questions/789448/choosing-between-bashrc-profile-bash-profile-etc


#GENERAL FIXES:
#TODO URGENT: TEST repo branch syntax = "action user/repo:branch" or "action repo branch"
#TODO URGENT: topic and builtin array type configs get duplicated (deps already done) need to filter symlinks.
#TODO URGENT: Add to manager.state when packages added to manager via 'dotsys action cmd package'


#FUTURE FEATURES
#TODO ROADMAP: When no primary repo, find existing repos and offer choices
#TODO ROADMAP: Give option to use builtin repo as user repo (specify repo as dotsys/builtins not dotsys/dotsys)
#TODO ROADMAP: handle .settings files
#TODO ROADMAP: FOR NEW Installs prompt for --force & --confirm options
#TODO ROADMAP: Detect platforms like babun and linux distros that give generic uname.
#TODO ROADMAP: Option to delete unused topics from user's .dotfies directory after install (NOT PRIMARY REPO)
#TODO ROADMAP: Option to collect topics from installed repos to primary repo, or create new repo from current config..

#QUESTIONS:
#TODO QUESTION: Currently .dotsysrc persists usr/local/bin on path, should we just permanently add to path file?
#TODO QUESTION: Change "freeze" to "show".. as in show status.  ie show brew, show state, show managers?
#TODO QUESTION: Hold all manager's package file installs to end of topic runs?
#TODO QUESTION: Currently repo holds user files, maybe installed topics should be copied to internal user directory.
# - Currently changes to dotfiles do not require a dotsys update since they are symlinked, the change would require this.
# - Currently if a repo is deleted the data is gone, the change would protect topics in use.



# Fail on errors.
# set -e

# Show executed commands
#set -x

# Dotsys debug system true/false
DEBUG=false

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
. "$DOTSYS_LIBRARY/configio.sh"
. "$DOTSYS_LIBRARY/terminalio.sh"
. "$DOTSYS_LIBRARY/state.sh"
. "$DOTSYS_LIBRARY/platforms.sh"
. "$DOTSYS_LIBRARY/scripts.sh"
. "$DOTSYS_LIBRARY/managers.sh"
. "$DOTSYS_LIBRARY/symlinks.sh"
. "$DOTSYS_LIBRARY/config.sh"
. "$DOTSYS_LIBRARY/repos.sh"
. "$DOTSYS_LIBRARY/stubs.sh"

DOTSYS_REPOSITORY="$(drealpath "$DOTSYS_REPOSITORY")"
DOTSYS_LIBRARY="$(drealpath "$DOTSYS_LIBRARY")"
debug "final DOTSYS_REPOSITORY: $DOTSYS_REPOSITORY"
debug "final DOTSYS_LIBRARY: $DOTSYS_LIBRARY"

#GLOBALS
STATE_SYSTEM_KEYS="installed_repo"
SYSTEM_FILES="install.sh uninstall.sh update.sh upgrade.sh freeze.sh manager.sh topic.sh dotsys.cfg"
SYSTEM_FILE_EXTENSIONS="sh symlink stub cfg dsbak yaml"

DEFAULT_APP_MANAGER=
DEFAULT_CMD_MANAGER=

# current active repo (set by load_config_vars)
ACTIVE_REPO=
ACTIVE_REPO_DIR=

# user info (set by set_user_vars)
USER_NAME=

# persist state for topic actions & symlinks
GLOBAL_CONFIRMED=

# persist state for topic actions only
TOPIC_CONFIRMED=

# persist state for symlink actions only
SYMLINK_CONFIRMED=

# Persist action confirmed for all packages
PACKAGES_CONFIRMED=

# Default dry run state is off
# use 'dry_run 0' to toggle on
# use 'if dry_run' to test for state
DRY_RUN_STATE=1
# Default dry run message is back space
DRY_RUN="\b"

# track mangers actively used by topics or packages
ACTIVE_MANAGERS=()
# track topics actively used by other topics (dependencies)
ACTIVE_TOPICS=()

# track uninstalled topics (populated but not used)
UNINSTALLED_TOPICS=()

# track installed topics (populated but not used)
INSTALLED=()

# Current platform
PLATFORM="$(get_platform)"
PLATFORM_USER_BIN="$(platform_user_bin)"

# Determines if logo,stats,and other verbose messages are shownm
VERBOSE_MODE=

# tracks if shown
SHOW_LOGO=0
SHOW_STATS=0


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
    freeze          Output installed state to terminal
                    use --log option to freeze to file

    <topics> optional:

    Limits action to specified topics (space separated list)
    Omit topic for all all available topics

    <limits> optional:

    -d | dotsys             Limit action to dotsys (excludes package management)
    -r | repo [branch]      Limit action to primary repo management defaults (not topics)
                            replace 'repo' with 'user/repo[:branch]' for alternate
                            freeze repo: Output repo config to file
                                         use --cfg option to set mode
    -l | links              Limit action to symlinks
    -m | managers           Limit action to package managers
    -s | scripts            Limit action to scripts
    -t | stubs              Limit action to stubs
    -f | from <user/repo>   Apply action to topics from specified repo master branch
                            optional alternate branch: <user/repo:branch>
    -p | packages           Limit action to package manager's packages
    -c | cmd                Limit action to cmd manager's packages
    -a | app                Limit action to app manager's packages

    <options> optional:     use to bypass confirmations.
    --force                 force action even if already completed
    --tlogo                 Toggle logo for this run only
    --tstats                Toggle stats for this run only
    --debug                 Turn on debug mode
    --dryrun                Runs through all tasks, but no changes are actually made (must confirm each task)
    --confirm               bypass topic confirmations and confirm symlinks for each topic
    --confirm default       install: repo
                            uninstall: original
    --confirm repo          install: use repo's dotfile and backup original version
                            uninstall: restore original or keep a copy of repo version
    --confirm original      install: use original dotfile and backup repo version
                            uninstall: restore original or none
    --confirm none          install: make the symlink, make no backup
                            uninstall: remove the symlink, do not restore backup

    --confirm dryrun        Same as dryrun option but bypasses confirmations
    --log                   Print everything to file located in .dotfiles/user/repo/<date>.dslog
    --cfg <mode>            Set mode for config output <default, user, topic, full>

    Usage Examples:

    - Perform action on all topics
      $ dotsys <action>

    - Perform action on one or more topics
      $ dotsys <action> vim tmux

    - Perform action on all topics and bypass confirmations
      $ dotsys <action> --confirm repo

    - Limit actions to a specific catagory
      $ dotsys <action> links

    - Manage primary repo:
      $ dotsys <action> repo

    - Actions on topics from other repos
      $ dotsys <action> <topics> from user/repo

    - Log actions to a file
      $ dotsys <action> --log mylog.txt

    - Create a config file from a repo
      $ dotsys freeze repo -cfg full

    Package Management:

    Packages do not require topics! The advantage of managing packages
    through dotsys insures that changes to your system are tracked by
    your repo.

    - Manage a command line utilities with default manager
      $ dotsys <action> cmd vim tmux

    - Manage an OS application with default manager
      $ dotsys <action> app google-chrome lastpass

    - Manage a specific manager's packages
      $ dotsys install brew packages vim tmux

    - Manage primary repository
      $ dotsys <action> repo

    - Manage a specific repository
      $ dotsys <action> user/repo


    Organization:       NOTE: Any file or directory prefixed with a "." will be ignored by dotsys


      repos:            .dotfiels/user_name/repo_name
                        A repo contains a set of topics and correlates to a github repository
                        You can install topics from as many repos as you like.

      symlinks:         topic/*.symlink
                        Symlinked to home or specified directory


      bins:             topic/bin
                        All files inside a topic bin will be available
                        on the command line by simlinking to dotsys/bin

      managers:         topic/manager.sh
                        Manages packages of some type, such as brew,
                        pip, npm, etc.. (see script manager.sh for details)

      configs:          Configs are yaml like configuration files that tell
                        dotsys how to handle a repo and or topics.  You can
                        customize almost everything about a repo and topic
                        behavior with dotsys.cfg file.
                        repo/dotsys.cfg repo level config file
                        topic/dotsys.cfg topic level config file

      stubs:            topic/file.stub
                        Stubs allow topics to collect user information and to add
                        functionality to each other. For example: The stub for
                        .vimrc is symlinked to your $HOME
                        directory where vim will read it.  The stub will then source
                        your vim/vimrc.symlink and search for other topic/*.vim files.

    scripts:            scripts are optional and placed in each topic root directory

      topic/topic.sh    A single script containing optional functions for each required
                        action (see function definitions)

      topic/manager.sh  Designates a topic as a manager. Functions handle packages not the manager!
                        Required functions for installing packages: install, uninstall, upgrade
                        Not supported: update & freeze as these are in the manager topic.sh file.
                        Also note: manager's topic.sh should allow upgrading of packages via upgrade.

      script functions: The rules below are important (please follow them strictly)

        install:        Makes permanent changes that only require running on initial install (run once)!

        uninstall       Must undo everything done by install (run once)!

        upgrade         Only use for changes that bump the installed component version!
                        Topics with a manager typically wont need this, the manager will handle it.

        update:         Only use to update dotsys with local changes or data (DO NOT BUMP VERSIONS)!
                        ex: reload a local config file so changes are available in the current session
                        ex: refresh data from a webservice

        freeze:         Output the current state of the topic
                        ex: A manager would list installed topics
                        ex: git will show the current status

    depreciated scripts:use topic.sh functions
      install.sh        see action function definitions
      uninstall.sh      see action function definitions
      upgrade.sh        see action function definitions
      update.sh         see action function definitions
    "

    check_for_help "$1"

    local action=

    case $1 in
        install )   action="install" ;;
        uninstall)  action="uninstall" ;;
        upgrade )   action="upgrade" ;;
        update )    action="update" ;;
        freeze)     action="freeze" ;;
        * )  error "Invalid action: $1"
           show_usage ;;
    esac
    shift

    local topics=()
    local limits=()
    local force
    local from_repo
    local from_branch
    local cfg_mode
    local LOG_FILE
    local recursive
    local topic
    local confirmed

    while [[ $# > 0 ]]; do
    case $1 in
        # limits
        -d | dotsys )   limits+=("dotsys") ;;
        -r | repo)      limits+=("repo")    #no topics permitted (just branch)
                        # repo not followed by option
                        if [ "$2" ] && [[ "$2" != "-"* ]]; then
                            from_branch="$2";shift
                        fi ;;
        -l | links)     limits+=("links") ;;
        -m | managers)  limits+=("managers") ;;
        -s | scripts)   limits+=("scripts") ;;
        -t | stubs)     limits+=("stubs") ;;
        -f | from)      from_repo="${2:-none}"; shift ;;
        -p | packages)  limits+=("packages") ;;
        -a | app)       limits+=("packages")
                        topics+=("app") ;;
        -c | cmd)       limits+=("packages")
                        topics+=("cmd") ;;

        # options
        --force)        force="$1" ;;
        --tlogo)        ! get_state_value "dotsys" "SHOW_LOGO"; SHOW_LOGO=$? ;;
        --tstats)       ! get_state_value "dotsys" "SHOW_STATS"; SHOW_STATS=$? ;;
        --debug)        DEBUG="true" ;;
        --recursive)    recursive="true" ;; # used internally for recursive calls
        --dryrun)       dry_run 0 ;;
        --confirm)      if [[ "$2" =~ (default|original|repo|none|skip) ]]; then
                            confirmed="$2"
                            if [ "$2" = "dryrun" ]; then
                                dry_run 0
                                confirmed="skip"
                            fi
                            shift
                        else
                            confirmed=true
                        fi ;;
        --log)          LOG_FILE="true";;
        --cfg)          cfg_mode="$2"; shift;;
        --*)            invalid_option ;;
        -*)             invalid_limit ;;
        *)              topics+=("$1") ;;
    esac
    shift
    done

    required_vars "action"

    debug "[ START DOTSYS ]-> a:$action t:${topics[@]} l:$limits force:$force conf:$confirmed r:$recursive from:$from_repo"

    # reset globals if non recursive call
    if ! [ "$recursive" ]; then
        GLOBAL_CONFIRMED=""
        TOPIC_CONFIRMED=""
        SYMLINK_CONFIRMED=""
        PACKAGES_CONFIRMED=""
        ACTIVE_REPO=
        ACTIVE_REPO_DIR=
    fi

    # SET CONFIRMATIONS
    if ! [ "$recursive" ]; then
        GLOBAL_CONFIRMED="$confirmed"
        # Set global if topics provided by user
        if [ "${topics[0]}" ] || [[ "$action" =~ (update|upgrade|freeze) ]]; then
            debug "main -> Set GLOBAL_CONFIRMED = backup (Topics specified or not install/uninstall)"
            GLOBAL_CONFIRMED="default"
        fi

        # override for dryrun option
        if dry_run; then
            GLOBAL_CONFIRMED="skip"
        fi

        TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"
        SYMLINK_CONFIRMED="$GLOBAL_CONFIRMED"
        PACKAGES_CONFIRMED="$GLOBAL_CONFIRMED"
    fi

    # HANDLE REPO LIMIT

    # First topic "repo" or "xx/xx" is equivalent to setting limits="repo"
    if topic_is_repo; then
        debug "main -> topic is repo: ${topics[0]}"
        limits+=("repo")
        from_repo="${topics[0]}"
        topics=()

    # allows syntax action "repo"
    elif [ ! "$from_repo" ] && in_limits "repo" -r; then
        debug "main -> repo is in limits"
        #from_repo="repo"
        topics=()
    fi

    # allow "repo" as shortcut to active repo
    if [ "$from_repo" = "repo" ] ; then
        #from_repo="$(get_active_repo)"
        from_repo=""
        if ! [ "$from_repo" ]; then
            error "There is no primary repo configured, so
            $spacer a repo must be explicitly specified"
            exit
        fi
    fi

    # LOGGING

    if [ "$LOG_FILE" ]; then
        LOG_FILE="$(repo_dir "$from_repo")/$(date '+%Y-%m-%d-%H-%M-%S').dslog"
        info "LOGGING TO FILE: $LOG_FILE"
        echo "date: $(date '+%d/%m/%Y %H:%M:%S')" > LOG_FILE
    fi

    # HANDLE DOTSYS LIMIT

    if in_limits "dotsys" -r; then

        debug "main -> DOTSYS IN LIMITS"
        from_repo="dotsys/dotsys"

        if [ "$action" = "uninstall" ]; then
            # PREVENT DOTSYS UNINSTALL UNTIL EVERYTHING ELSE IS UNINSTALLED!
            if user_topics_installed; then
                warn "Dotsys is still in use and cannot be uninstalled until
              $spacer all topics, packages, & repos are uninstalled\n"
                get_user_input "Would you like to uninstall everything, including dotsys, now?" --required
                if ! [ $? -eq 0 ]; then exit; fi
            fi
        fi
    fi

    verbose_mode

    if ! [ "$recursive" ]; then
        set_user_vars
        print_logo
    fi

    debug "main final -> a:$action t:${topics[@]} l:$limits force:$force r:$recursive from:$from_repo"
    debug "main final -> GC:$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED verbose:$VERBOSE_MODE"


    # freeze dotsys state files
    if [ "$action" = "freeze" ] && in_limits "dotsys"; then
        freeze_states "${limits[@]}"
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

    # HANDLE PACKAGE LIMIT (requires load_config_vars)

    # This allows dotsys to manage packages without a topic directory
    # <manager> may be 'cmd' 'app' or specific manager name
    # for example: 'dotsys install <manager> packages <packages>'   # specified packages
    # for example: 'dotsys install <manager> packages file'         # all packages in package file
    # for example: 'dotsys install <manager> packages'              # all installed packages
    # TODO: Consider api format 'dotsys <manager> install <package>'
    if in_limits "packages" -r && is_manager "${topics[0]}" && [ ${#topics[@]} -gt 1 ] ; then
      local manager="${topics[0]}"
      topics=( "${topics[@]/${topics[0]}}" )
      debug "main -> packages limit $action $manager ${limits[@]} ${topics[@]} $force"
      manage_packages "$action" "$manager" packages ${topics[*]} "$force"
      return
    fi

    # END REPO LIMIT if repo in limits dotsys has ended
    if in_limits -r "repo"; then
        return
    fi

    # TOPIC LIST

    if ! [ "$topics" ]; then

        if ! [ "$ACTIVE_REPO_DIR" ]; then
            error "Could not resolve active repo directory
                 \rrepository : $ACTIVE_REPO
                 \rdirectory  : $ACTIVE_REPO_DIR"
            msg "$( printf "Run %bdotsys install%b to configure a repo%s" $code $yellow "\n")"
            return 1
        fi

        # Use from repo to limit actions to toppic from a specific repo
        debug "main -> get_topic_list $from_repo $force"
        local list="$(get_topic_list "$from_repo" "$force")"

        # Handle no topics found
        if ! [ "$list" ]; then
            if [ "$action" = "install" ]; then
                msg "\nThere are no topics in" "$( printf "%b$(repo_dir "$(get_active_repo)")\n" $thc)"
            else
                msg "\nThere are no topics installed by dotsys to" "$action\n"
            fi
            if [ "$action" = "install" ]; then
                copy_topics_to_repo "$(get_active_repo)"
                add_existing_dotfiles "$(get_active_repo)"
                # Check for topics again
                list="$(get_topic_list "$from_repo" "$force")"
            fi
        fi

        topics=( $list )

        # Uninstall is more efficient with reversed order
        if [ "$action" = "uninstall" ]; then
            reverse_array topics
        fi

        debug "main -> final topics list: ${topics[*]}"
    fi

    # Collect user data
    if ! [ "$recursive" ] && [ "$action" = "install" ] && in_limits "stubs" "dotsys"; then
        debug "main -> collect_user_data"
        manage_stubs "$action" "${topics[*]}" --data "$force"
    fi

    # ITERATE TOPICS

    debug "main -> TOPIC LOOP START"

    for topic in ${topics[@]};do

        debug "main -> Handling topic: $topic"

        # ABORT: NON EXISTANT TOPICS
        if ! topic_exists "$topic"; then
            # error message supplied by topic_exits
            continue
        fi

        # LOAD TOPIC CONFIG (must be HERE)
        load_topic_config_vars "$topic"

        # ABORT: on platform exclude (after config loaded)
        if topic_excluded "$topic"; then
            #task "Excluded" "$(printf "%b${topic}" $thc)" "on $PLATFORM"
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
                debug "*** create sate file for $topic"
                touch "$(state_file "$topic")"
                # set active (prevents running manager tasks more then once)
                ACTIVE_MANAGERS+=("$topic")

            # uninstall is a bit different
            else

                # on uninstall we need to remove packages from package file first (or it will always be in use)
                if manager_in_use && in_limits "packages"; then
                    debug "main -> UNINSTALL MANAGER PACKAGES FIRST: $topic"
                    manage_packages "$action" "$topic" file "$force"
                fi

                # ABORT: uninstall if it's still in use (uninstalled at end as required).
                if manager_in_use "$topic"; then
                    warn "Manager" "$(printf "%b$topic" $thc)" "is in use and can not be uninstalled yet."
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
                    ACTIVE_MANAGERS=("${ACTIVE_MANAGERS[@]/$topic}")
                fi
            fi

        # ABORT: Non manager topics when limited to managers
        else
            if in_limits "managers" -r; then
                debug "main -> ABORT: manager in limits and $topic is not a manger"
                continue
            fi
        fi


        # ABORT: on install if already installed (override --force)
        debug "main -> check is_installed for $topic $ACTIVE_REPO"
        local action_complete=

        if ! [ "$force" ]; then

            if [ "$action" = "install" ] && is_installed "dotsys" "$topic"; then

               # Check if topic is installed from active repo
               if is_installed "dotsys" "$topic" "$ACTIVE_REPO";then
                    action_complete="$ACTIVE_REPO"

               # Check if topic is installed from another repo (not dotsys)
               elif is_installed "dotsys" "$topic" "!dotsys/dotsys";then
                    action_complete="$(get_state_value "dotsys" "$topic" "!dotsys/dotsys")"

                    # Option to replace existing topic or
                    get_user_input "$topic is installed from $action_complete, do you want
                            $spacer to replace it with the version from $ACTIVE_REPO?" -r
                    if [ $? -eq 0 ]; then
                        #TODO URGENT: ACTIVE_REPO should not be global, just pass to recursive calls
                        prev_active_repo="$ACTIVE_REPO"
                        dotsys uninstall "$topic" links scripts stubs from "$action_complete"
                        #limits=(${linits[*]:-links scripts})
                        pre_stub=""
                        load_config_vars "$prev_active_repo" "$action"
                        action_complete=""
                    fi
               fi


            elif [ "$action" = "uninstall" ]; then

                # ABORT: if not installed for active repo
                if ! is_installed "dotsys" "$topic" "$ACTIVE_REPO"; then
                    action_complete="$ACTIVE_REPO"

                # Catch uninstall from alternate repo when topic exists in primary repo
                elif ! [ "$limits" ] && [ "$ACTIVE_REPO" != "$(state_primary_repo)" ] && [ -d "$(topic_dir "$topic" "primary")" ];then

                    # Option to reinstall from primary repo
                    get_user_input "After $topic is uninstalled from $ACTIVE_REPO, Would you like to
                            $spacer reinstall it from your primary repo $(state_primary_repo)?" -r
                    if [ $? -eq 0 ]; then
                        prev_active_repo="$ACTIVE_REPO"
                        dotsys uninstall "$topic" links scripts stubs from "$ACTIVE_REPO"
                        dotsys install "$topic" links scripts stubs from $(state_primary_repo)
                        load_config_vars "$prev_active_repo" "$action"
                        continue
                    fi
                fi
            fi

            if [ "$action_complete" ]; then
                task "Already ${action}ed" "$(printf "%b$topic" $thc )" "from $action_complete"
                continue
            fi
        fi

        # CONFIRM / ABORT DOTSYS UNINSTALL

        if [ "$topic" = "core" ] && [ "$action" = "uninstall" ]; then

            # running 'dotsys uninstall' will attempt to remove dotsys since it's in the state
            if ! in_limits "dotsys" -r; then continue; fi

            # Dotsys is expicity being uninstalled with 'dotsys uninstall dotsys'
            get_user_input "$(printf "%bAre you sure you want to remove the 'dotsys' command
                              $spacer and it's required components from your system?%b" $red $rc)" --required

        # CONFIRM TOPIC
        else
            debug "main -> call confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"
            confirm_task "$action" "" "${limits[*]:-\b} $topic"
            if ! [ $? -eq 0 ]; then continue; fi
            debug "main -> post confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"
        fi

        # ALL CHECKS DONE START THE ACTION

        # 1) dependencies
        if in_limits "scripts" "dotsys"; then
            manage_dependencies "$action" "$topic"
            # TOPIC HAS DEPENDANTS AND CAN NOT BE UNINSTALLED YET
            if ! [ $? -eq 0 ]; then continue; fi
        fi

        # 2) managed topics
        if in_limits "managers" "dotsys"; then
            run_manager_task "$topic" "$action" "$topic" "$force"
        fi

        # 3) scripts
        if in_limits "scripts" "dotsys"; then
            debug "main -> call run_topic_script"
            run_topic_script "$action" "$topic"
        fi

        # 4) Stubs (before symlinks)
        if in_limits "stubs" "links" "dotsys"; then
             debug "main -> manage_topic_stubs"
             manage_topic_stubs "$action" "$topic" "$force"
        fi

        # 5) symlinks
        if in_limits "links" "dotsys"; then
            debug "main -> call symlink_topic: $action $topic confirmed? gc:$GLOBAL_CONFIRMED tc:$TOPIC_CONFIRMED"
            symlink_topic "$action" "$topic"
        fi

        # 6) packages
        if is_manager  && [ "$action" != "uninstall" ] && in_limits "packages"; then
            debug "main -> call manage_packages"
            manage_packages "$action" "$topic" file "$force"
        fi

        # track uninstalled topics
        if [ "$action" = "uninstall" ]; then
           UNINSTALLED_TOPICS+=(topic)
        fi

        # record to state file
        if [ "$action" = "install" ]; then

            # add to state file if not there
            state_install "dotsys" "$topic" "$(get_active_repo)"
            INSTALLED+=($topic) # not used any more
        # uninstalled
        elif [ "$action" = "uninstall" ]; then
          # remove topic form state file
          state_uninstall "dotsys" "$topic" "$(get_active_repo)"
          INSTALLED=( "${INSTALLED[@]/$topic}" ) # not used any more
        fi

    done

    debug "main -> TOPIC LOOP END"

#    # When installing we have to manage the stubs last and add shell to topics
#    if [ "$action" = "install" ] && in_limits "stubs" "links"; then
#        debug "main -> manage stub files for installed topics"
#        manage_stubs "$action" "${topics[*]}" --task "$force"
#    fi

    # Finally check for repos, managers, & topics that still need to be uninstalled
    if [ "$action" = "uninstall" ]; then

        # Check for inactive managers to uninstall
        uninstall_inactive "managers"
        # Check for inactive topics uninstall
        uninstall_inactive "topics"

        # Check if all repo topics are uninstalled
        ACTIVE_REPO="${ACTIVE_REPO:-dotsys/dotsys}"
        if in_limits "repo" "dotsys" && ! repo_in_use "$ACTIVE_REPO"; then
            debug "main -> REPO NO LONGER USED uninstalling"
            manage_repo "uninstall" "$ACTIVE_REPO" "$force"
            debug "main -> FINISHED (repo uninstalled)"
            exit
        fi
    fi

    debug "main -> FINISHED"
}

uninstall_inactive () {

    # Check for inactive topics to uninstall
    local active="ACTIVE_$(echo "$1" | tr '[:lower:]' '[:upper:]' )"
    local active_array
    # if your interpreter shows and error here igore it, its fine!
    eval "active_array=( \"\${$active[@]}\" )"
    local in_use="$(echo "${1%s}" | tr '[:upper:]' '[:lower:]')_in_use"
    local inactive=()
    local t

    debug "-- uninstall_inactive $1"

    for t in ${active_array[@]}; do
        [[ "${topics[@]}" =~ "$t" ]]
        debug "   [[ $t in topics ]] = $?"
        if ! $in_use "$t" && [[ "${topics[@]}" =~ "$t" ]]; then
            debug "   uninstall_inactive found INACTIVE $1: $t"
            inactive+=("$t");
        fi
    done

    if [ "${inactive[@]}" ]; then
        debug "   uninstall_inactive -> dotsys uninstall ${inactive[@]} ${limits[@]} --recursive"
        dotsys uninstall ${inactive[@]} ${limits[@]} --recursive
    fi
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
