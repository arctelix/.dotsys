#!/bin/sh

# Main entry point and command handler
#
# Author: arctelix
#
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles
#
# Other useful reference
# http://superuser.com/questions/789448/choosing-between-bashrc-profile-bash-profile-etc
#
# Licence: The MIT License (MIT)
# Copyright (c) 2016 Arctelix https://github.com/arctelix
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# INSTALL FIXES:
#TODO URGENT: manage_topic_bin needs to be incorporated into main or symlink process? also needs freeze
#TODO URGENT: shell topic is required for other shells to work and needs to be installed when dotsys is installed!

# GENERAL FIXES:
#DONE URGENT: Prevent uninstalling topics with DEPS before their dependants are uninstalled!
#DONE URGENT: move installed_repo keys into repo.state (its better for freeze and other lookups)
#TODO URGENT: TEST new repo branch syntax = "action user/repo:branch" or "action repo branch"
#TODO URGENT: topic and builtin array type configs get duplicated (deps already done) need to filter symlinks.
#TODO URGENT: Record to manager package file when packages added to manager via 'dotsys action cmd package'

#TODO: When no primary repo, find existing repos and offer choices, including builtin repo..

# FUTURE FEATURES
#TODO ROADMAP: handle .settings files
#TODO ROADMAP: FOR NEW Installs prompt for --force & --confirm options
#TODO ROADMAP: Finish implementing func_or_func_msg....
#TODO ROADMAP: Detect platforms like babun and linux distros that give generic uname.
#TODO ROADMAP: Option to delete unused topics from user's .dotfies .directory after install (NOT PRIMARY REPO)
#TODO ROADMAP: Option to move topics from installed repos to primary repo, or create new repo from current config..

# QUESTIONS:
#TODO QUESTION: Change "freeze" to "show".. as in show status.  ie show brew, show state, show managers?
#TODO QUESTION: Symlink "(o)ption all" choices should apply to all topics (currently just for one topic at a time)?
#TODO QUESTION: Hold manager's packages install to end of topic runs?
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

# path to platform's system user bin
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
    -f | from <user/repo>   Apply action to topics from specified repo master branch
                            optional alternate branch: <user/repo:branch>
    -p | packages           Limit action to package manager's packages
    -c | cmd                Limit action to cmd manager's packages
    -a | app                Limit action to app manager's packages

    <options> optional: use to bypass confirmations.
    --force             force action even if already completed
    --tlogo             Toggle logo for this run only
    --tstats            Toggle stats for this run only
    --debug             Turn on debug mode
    --dryrun            Runs through all tasks, but no changes are actually made (must confirm each task)
    --confirm           bypass topic confirmations and confirm symlinks for each topic
    --confirm default   install: repo
                        uninstall: original
    --confirm repo      install: use repo's dotfile and backup original version
                        uninstall: restore original or keep a copy of repo version
    --confirm original  install: use original dotfile and backup repo version
                        uninstall: restore original or none
    --confirm none      install: make the symlink, make no backup
                        uninstall: remove the symlink, do not restore backup

    --confirm dryrun    Same as dryrun option but bypasses confirmations
    --log               Print everything to file located in .dotfiles/user/repo/<date>.dslog
    --cfg <mode>        Set mode for config output <default, user, topic, full>

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

    Packages do not require topics! The advantage managing packages
    through dotsys insures that they will be added / remove from your
    repo configuration the next time you install or uninstall with dotsys.

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

        install:          Makes permanent changes that only require running on initial install (run once)!

        uninstall         Must undo everything done by install (run once)!

        upgrade           Only use for changes that bump the installed component version!
                          Topics with a manager typically wont need this, the manager will handle it.

        update:           Only use to update dotsys with local changes or data (DO NOT BUMP VERSIONS)!
                          ex: reload a local config file so changes are available in the current session
                          ex: refresh data from a webservice

        freeze:           Output the current state of the topic
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
        -f | from)      from_repo="$2"; shift ;;
        -p | packages)  limits+=("packages") ;;
        -a | app)       limits+=("packages") ;;
        -c | cmd)       limits+=("packages") ;;

        # options
        --force)        force="$1" ;;
        --tlogo)        ! get_state_value "SHOW_LOGO"; SHOW_LOGO=$? ;;
        --tstats)       ! get_state_value "SHOW_STATS"; SHOW_STATS=$? ;;
        --debug)        DEBUG="true" ;;
        --recursive)    recursive="true" ;; # used internally for recursive calls
        --dryrun)       dry_run 0 ;;
        --confirm)      if [[ "$2" =~ (default|original|repo|none|skip) ]]; then
                            GLOBAL_CONFIRMED="$2"
                            if [ "$2" = "dryrun" ]; then
                                dry_run 0
                                GLOBAL_CONFIRMED="skip"
                            fi
                            shift
                        else
                            GLOBAL_CONFIRMED=true
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

    debug "[ START DOTSYS ]-> a:$action t:${topics[@]} l:$limits force:$force conf:$GLOBAL_CONFIRMED r:$recursive from:$from_repo"

    # SET CONFIRMATIONS
    if ! [ "$recursive" ]; then
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
    fi

    # DIRECT MANGER PACKAGE MANAGEMENT
    # This allows dotsys to manage packages without a topic directory
    # <manager> may be 'cmd' 'app' or specific manager name
    # for example: 'dotsys install <manager> packages <packages>'   # specified packages
    # for example: 'dotsys install <manager> packages file'         # all packages in package file
    # for example: 'dotsys install <manager> packages'              # all installed packages
    # TODO: Consider api format 'dotsys <manager> install <package>'
    if in_limits "packages" -r && is_manager "${topics[0]}" && [ ${#topics[@]} -gt 1 ] ; then
      local manager="$(get_default_manager "${topics[0]}")" # checks for app or cmd
      local i=0 # just to make my syntax checker not fail (weird)
      unset topics[$i]
      debug "main -> ONLY $action $manager ${limits[@]} ${topics[@]} $force"
      manage_packages "$action" "$manager" ${topics[@]} "$force"
      return
    fi

    # HANDLE REPO LIMIT

    # First topic "repo" or "xx/xx" is equivalent to setting limits="repo"
    if topic_is_repo; then
        debug "main -> topic is repo: ${topics[0]}"
        limits+=("repo")
        from_repo="${topics[0]}"
        topics=

    # allows syntax action "repo"
    elif [ ! "$from_repo" ] && in_limits "repo" -r; then
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

    # LOGGING

    if [ "$LOG_FILE" ]; then
        LOG_FILE="$(repo_dir "$from_repo")/$(date '+%Y-%m-%d-%H-%M-%S').dslog"
        info "LOGGING TO FILE: $LOG_FILE"
        echo "date: $(date '+%d/%m/%Y %H:%M:%S')" > LOG_FILE
    fi

    # HANDLE DOTSYS LIMIT

    # sets repo to $DOTSYS_REPOSITORY
    # Runs builtin dotsys topic only
    if in_limits "dotsys" -r; then
        # PREVENT DOTSYS UNINSTALL UNTIL EVERYTHING ELSE IS UNINSTALLED!
        if [ "$action" = "uninstall" ] && dotsys_in_use; then
                error "Dotsys can not be uninstalled until all t
              $sdpacer topics, packages, & repos are uninstalled"
                continue
        fi
        debug "DOTSYS IN LIMITS"
        topics=("dotsys")
        #limits=("${limits[@]/dotsys}")
        from_repo="dotsys/dotsys"
    fi

    # Verbose, logo, user
    if ! [ "$recursive" ]; then
        verbose_mode
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
                msg "$( printf "\nThere are no topics in %b$ACTIVE_REPO_DIR\n%b" $green $yellow)"
            else
                msg "$( printf "\nThere are no topics %binstalled by dotsys%b to $action\n" $green $yellow)"
            fi
            if [ "$action" = "install" ]; then
                copy_topics_to_repo "$ACTIVE_REPO"
                add_existing_dotfiles "$ACTIVE_REPO"
                # Check for topics again
                list="$(get_topic_list "$ACTIVE_REPO_DIR" "$force")"
            fi
        fi
        topics=("$list")
        debug "main -> topics list:\n\r$topics"
        debug "main -> end list"
    fi

    # We stub here rather then during symlink process
    # to get all user info up front for auto install
    if [ "$action" = "install" ] || [ "$action" = "upgrade" ] && in_limits "links" "dotsys"; then
        manage_stubs "$action" "${topics[@]}" "$force"
    fi

    # Iterate topics

    debug "main -> TOPIC LOOP START"

    local topic

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
            #task "$(printf "Excluded %b${topic}%b on $PLATFORM" $green $cyan)"
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
        if [ "$action" = "install" ] && is_installed "dotsys" "$topic" "$ACTIVE_REPO" && ! [ "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        # ABORT: on uninstall if not installed (override --force)
        elif [ "$action" = "uninstall" ] && ! is_installed "dotsys" "$topic" && ! [ "$force" ]; then
           task "$(printf "Already ${action}ed %b$topic%b" $green $rc)"
           continue
        fi

        # CONFIRM TOPIC
        debug "main -> call confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"
        confirm_task "$action" "" "$topic" "${limits[@]}"
        if ! [ $? -eq 0 ]; then continue; fi
        debug "main -> post confirm_task status: GC=$GLOBAL_CONFIRMED TC=$TOPIC_CONFIRMED"


        # ALL CHECKS DONE START THE ACTION

        # 1) dependencies
        if in_limits "scripts" "dotsys"; then
            manage_dependencies "$action" "$topic"
            # Topic is in use by other topics
            if ! [ $? -eq 0 ]; then continue; fi
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
        if is_manager  && [ "$action" != "uninstall" ] && in_limits "packages"; then
            debug "main -> call manage_packages"
            manage_packages "$action" "$topic" file "$force"
        fi

        # track uninstalled topics
        if [ "$action" = "uninstall" ]; then
           UNINSTALLED_TOPICS+=(topic)
        fi
    done

    debug "main -> TOPIC LOOP END"

    # Finally check for repos, managers, & topics that still need to be uninstalled
    if [ "$action" = "uninstall" ]; then

        # Check for inactive managers to uninstall
        uninstall_inactive "managers"
        # Check for inactive topics uninstall
        uninstall_inactive "topics"

        # Check if all repo topics are uninstalled
        if in_limits "repo" && ! repo_in_use "$ACTIVE_REPO"; then
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
    debug "main -> clean inactive:$1"
    debug "main -> $active:\n${active_array[@]}"
    debug "main -> topics:\n${topics[@]}"

    for t in ${active_array[@]}; do
        [[ "${topics[@]}" =~ "$t" ]]
        debug "[[ $t in topics ]] = $?"
        if ! $in_use "$t" && [[ "${topics[@]}" =~ "$t" ]]; then
            debug "main -> ADDING INACTIVE $1: $t"
            inactive+=("$t");
        fi
    done
    debug "main -> INACTIVE $1: ${inactive[@]}"
    if [ "$inactive" ]; then
        debug "main -> uninstall inactive managers: $inactive"
        dotsys uninstall ${inactive[@]} ${limits[@]} --recursive --force
    fi
}

dotsys_in_use () {
    # if anything is in dotsys state file it's in use
    in_state "dotsys" "" "dotsys/dotsys"
    local r=$?
    debug "   - dotsys_in_use = $r"
    return $r
}
