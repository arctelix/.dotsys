#!/usr/bin/env bash

manage_repo (){


    local usage="manage_repo <action> <repo> [<branch> <options>]"
    local usage_full="Installs and uninstalls dotsys.
    --force           Force the repo management
    --confirmed       Pre-confirm repo action
    --cfg             Specify config file output mode
    "
    local action
    local repo
    local force
    local REPO_CONFIRMED
    local GIT_CONFIRMED
    local cfg_mode="${cfg_mode}"

    if [ "$GLOBAL_CONFIRMED" ] || in_limits "repo" -r; then
        REPO_CONFIRMED="true"
        GIT_CONFIRMED="true"
    fi

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )       force="$1" ;;
        --confirmed )   REPO_CONFIRMED="true" ;;
        --cfg )         cfg_mode="$2"; shift ;;
        *)  uncaught_case "$1" "action" "repo";;
        esac
        shift
    done

    required_vars "action" "repo"

    # separate repo & branch from repo:branch
    local branch="master"
    _split_repo_branch

    debug "-- manage_repo: received  a:$action r:$repo b:$branch $force"

    local remote_repo
    if is_dotsys_repo;then
        remote_repo="https://github.com/arctelix/.dotsys"
    else
        remote_repo="https://github.com/${repo}"
    fi

    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"
    local repo_user="$(cap_first ${repo%/*})"
    local repo_name="${repo#*/}"
    local state_key="installed_repo"
    local state_file="repos"

    debug "   manage_repo: final ->  a:$action r:$repo lr:$local_repo b:$branch $force"


    # make sure git is installed
    if ! cmd_exists git;then
        dotsys install cmd git --recursive
    fi

    local installed=
    local repo_status=

    # determine repo status
    if is_installed "$state_file" "$state_key" "$repo"; then
        installed="true"
        if [ -d "$local_repo" ]; then
            repo_status="installed"
            checkout_branch "$repo" "$branch"
        else
            repo_status="missing"
        fi
    # existing uninstalled local repo
    elif [ -d "$local_repo" ]; then
        info "Local directory exists: $local_repo"
        repo_status="local"
    else
        # check for remote
        debug "   check for remote #1"
        info "Checking for remote:
      $spacer $remote_repo"
        # remote repo found
        if has_remote_repo "$repo"; then
            info "Found remote repo: $remote_repo"
            repo_status="remote"
        # no remote repo or directory
        else
            info "New repo specified: $local_repo"
            repo_status="new"
        fi
    fi

    debug "   manage_repo status: $repo_status"

    # Check for action already complete (we do this first in case of status changes in checks)
    # Always set complete when repo not in limits.  Check force when repo in limits.
    if ! in_limits "repo" -r || ! [ "$force" ]; then
        if [ "$action" = "install" ] && [ "$repo_status" = "installed" ]; then
            complete="true"

        elif [ "$action" = "uninstall" ] && [ ! "$repo_status" = "installed" ]; then
            complete="true"
        fi
    fi


    # PRECONFIRM CHECKS AND MESSAGES

    # NOTE: REPO ACTIONS ARE HANDLED FIRST (EXCEPT UNINSTALL IS LAST!)

    # install expects nothing
    if [ "$action" != "install" ]; then

        # ALL ACTIONS except install

        # missing directory (installed)
        if [ "$repo_status" = "missing" ] && repo_in_use "$repo" && ! [ "$force" ]; then
            error "$(printf "The local repo $repo is $repo_status
                    $spacer and can not be ${action%e}ed.  If a remote repo exists
                    $spacer run 'dotsys install $repo' before ${action%e}ing.
                    $spacer Otherwise replace the repo with it's entire contents.
                    $spacer As a last resort run 'dotsys uninstall $repo --force'.")"
            exit

        # directory not found and (not installed)
        elif [ ! "$installed" ] && ! [ -d "$local_repo" ]; then
           error "$(printf "The repo $repo
                    $spacer was not found and can not be ${action%e}ed.
                    $spacer Check the spelling and make sure it is located
                    $spacer in $(dotfiles_dir).")"
           exit
        # directory exists but not installed
        elif [ ! "$installed" ]; then
            error "$(printf "The $repo_status repo $repo must be
                    $spacer installed before it can be ${action%e}ed.")"
            exit

        # UNINSTALL ONLY

        elif [ "$action" = "uninstall" ]; then
            if [ "$repo_status" = "missing" ]; then
                if repo_in_use "$repo" && [ "$force" ]; then
                    warn "$(printf "You are about to force the uninstall of a repo which no longer
                            $spacer exists and may not be fully uninstalled from your system.
                            $spacer The best course of action is abort now and replace the missing
                            $spacer repo in your $(dotfiles_dir) and run 'dotsys install $repo'")"
                    REPO_CONFIRMED=""
                fi
            # Abort on repo in use
            elif repo_in_use "$repo"; then
               error "$(printf "The repo $repo is in use and can not be uninstalled yet.
                        $spacer You must first run 'dotsys uninstall from $repo'")"
               exit

            # ok to remove unused repo without confirm
            else
               repo_status="unused"
               task "Uninstall $repo_status repo:" "$(printf "%b$repo" "$hc_topic")"
               REPO_CONFIRMED="true"
            fi

        # ALL EXCEPT UNINSTALL

        else

            # Check for git and convert to install
            if ! [ -d "${local_repo}/.git" ];then
                warn "The local repo" "$(printf "%b$repo" "$hc_topic")" "is not initialized for git."
                action="install"
            fi
        fi

    fi

    # ABORT: ACTION ALREADY DONE (we do this after the checks to make sure status has not changed)
    if [ "$complete" ]; then
        # Only show the complete message when we are installing a repo!
        if in_limits "repo" -r; then
            task "Already ${action%e}ed:" "$(printf "%b$repo" "$hc_topic")"
        fi
        return
    # CONFIRM
    else
        confirm_task "$action" "" "$repo_status repo $repo:$branch" "-> $local_repo" --confvar "REPO_CONFIRMED"
        if ! [ $? -eq 0 ]; then
            if [ "$action" = install ]; then

                msg_help "$spacer A repo must be installed before it can be used:
                          $spacer to install another repo locally use : " "dotsys install user/repo\n" \
                         "$spacer to install topics from another repo : " "dotsys install from user/repo"
                exit
            else
                return
            fi
        fi
    fi

    local action_status=1

    # ACTION INSTALL
    if [ "$action" = "install" ]; then

        if [ "$repo_status" = "missing" ] && has_remote_repo; then
            repo_status="remote"
        fi

        # REMOTE: Clone existing repo
        if [ "$repo_status" = "remote" ];then
            clone_remote_repo "$repo"

        # create full repo directory (after remote: or clone will fail)
        elif [ "$repo_status" != "local" ];then
            mkdir -p "$local_repo"
            if ! [ $? -eq 0 ]; then error "Local repo $local_repo could not be created"; exit; fi
        fi

        # GIT CONFIG (after remote: need existing configs)
        setup_git_config "$repo" "local"


        # make sure repo is git!
        if ! is_git; then
            init_local_repo "$repo"
            if ! [ $? -eq 0 ]; then
                msg "Dotsys requires git to function properly"; exit
            fi
        fi

        # Check EXISTING/INSTALLED status
        if ! is_dotsys_repo && [ "$repo_status" != "remote" ] && [ "$repo_status" != "new" ];then
            debug "   local directory/installed check for remote"
            if has_remote_repo "$repo"; then
                manage_remote_repo "$repo" auto
            else
                repo_status="new"
            fi
        fi

        # Make sure all repos have required files!
        install_required_repo_files "$repo"

        # NEW: initialize remote repo
        if [ "$repo_status" = "new" ];then
            init_remote_repo "$repo"
            msg "$spacer Don't forget to add topics to your new repo..."
        fi

        # Moved to main
        #create_all_req_stubs

        # MAKE PRIMARY if not offer some options
        debug "checi if: state primary repo = current repo"
        debug "$(state_primary_repo) = $repo"
        if ! is_dotsys_repo && [ "$(state_primary_repo)" != "$repo" ]; then

            # preview repo and confirm install
            if [ "$repo_status" != "new" ]; then
                confirm_task "preview" "repo" "config ${repo}" "-> ${repo}/.dotsys-default.cfg" --confvar ""
                if [ "$?" -eq 0 ]; then
                    create_config_yaml "$repo" | indent_lines
                    if [ $? -eq 0 ]; then
                        get_user_input "Would you like to install this repo?" -r
                        if ! [ $? -eq 0 ]; then
                            msg "Repo installation aborted"; exit
                        fi
                    fi
                fi
            fi

            confirm_make_primary_repo "$repo"
        fi

        state_install "$state_file" "$state_key" "$repo"
        action_status=$?

    elif [ "$action" = "update" ];then
        git_commit "$repo"
        action_status=$?

    elif [ "$action" = "upgrade" ]; then
        manage_remote_repo "$repo" auto --confirmed
        action_status=$?

    elif [ "$action" = "freeze" ]; then
        # list installed repos
        create_config_yaml "$repo" | indent_lines
        return
    elif [ "$action" = "uninstall" ]; then
        if repo_in_use "$repo" && ! [ "$force" ]; then
            # in use uninstall not permitted
            fail "$(printf "The repo $repo is in use and can not be uninstalled yet.
                    $spacer You must first run 'dotsys uninstall from $repo'")"
            exit
        fi
        # remove from state (check for installed and user default)
        state_uninstall "$state_file" "$state_key" "$repo"
        #state_uninstall "user" "user_repo" "$repo"
        action_status=$?

        # confirm delete if repo exists
        if [ -d "$local_repo" ] && has_remote_repo "$repo"; then
            manage_remote_repo "$repo" push
            # delete local repo (only if remote is pushed)
            if [ $? -eq 0 ]; then
                get_user_input "Would you like to delete local repo $repo?" --true no --false yes --confvar "" -d no -r
                if ! [ $? -eq 0 ]; then rm -rf "$local_repo"; fi
            fi
        fi
    fi

    # Success / fail message
    success_or_fail $action_status "$action" "$repo_status repo" "$(printf "%b$local_repo" "$hc_topic")"
    return $action_status
}


manage_remote_repo (){

    local usage="manage_remote_repo [<action>]"
    local usage_full="
    Actions:
    auto            Automatically push, pull or up-to-date
    status          Just get the auto status of the repo (do nothing)
    push            Push local changes to remote if behind
    pull            Pull remote changes to local if behind
    "
    local repo="$1"; shift
    local task
    local message
    local confirmed
    local branch="${branch:-master}"
    local ret_val=0
    local state

    while [[ $# > 0 ]]; do
    case "$1" in
      auto )        task="$1" ;;
      push )        task="$1" ;;
      pull )        task="$1" ;;
      status )      task="$1" ;;
      --message )   message="$1" ;;
      --confirmed )   confirmed="--confirmed" ;;
      * ) invalid_option "$1";;
    esac
    shift
    done

    required_vars "repo" "task"

    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local result

    debug "-- manage_remote_repo: $task b:$branch"
    debug "-- manage_remote_repo local_repo: $local_repo"
    debug "-- manage_remote_repo remote_repo: $remote_repo"


    # http://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
    # must run 'git fetch' or 'git remote update' first

    cd "$local_repo"

    # Update from remote
    debug "   manage_remote_repo: git remote update"
    result="$(git remote update 2>&1)"
    if ! [ $? -eq 0 ] || ! [ "$result" ]; then
        if ! [ "$task" = "status" ]; then
            debug "   manage_remote_repo: git remote update failed"
            fail "$(indent_lines "${result:-"No remote configured for repo"}")"

            # Make sure repo is initialized
            init_local_repo "$repo"

            # Update from remote again
            result="$(git remote update 2>&1)"
            info "$(indent_lines "${result}")";

        else
            error "git remote update failed"
            exit
        fi

    elif ! [ "$task" = "status" ]; then
        info "$(indent_lines "${result}")";
    fi

    # Make sure upstram is configured
    debug "   manage_remote_repo: git rev-parse"
    if ! git rev-parse @{u} > /dev/null 2>&1; then
        debug "   manage_remote_repo: git rev-parse failed attempting git checkout $branch"

        # Make sure branch is checked out (sets origin automatically)
        result="$(git checkout $branch > /dev/null 2>&1)"
        if ! [ "$task" = "status" ]; then
            success_or_fail $? "" "$(indent_lines "$result")"
        fi

        # unknown error
        if ! [ $? -eq 0 ]; then
            debug "   manage_remote_repo: git checkout $branch failed"
            error "Could not resolve issues with your repo, please fix it manually"
        fi
    fi

    # make sure everything is committed or we'll get a false reading
    git_commit "$repo" "$message"

    cd "$local_repo"
    # Determine git status
    debug "   manage_remote_repo: check status local"
    local LOCAL=$(git rev-parse @)
    debug "   manage_remote_repo: check status remote"
    local REMOTE=$(git rev-parse @{u})
    debug "   manage_remote_repo: check status base"
    local BASE=$(git merge-base @ @{u})
    debug "   manage_remote_repo: determine status"
    if [ $LOCAL = $REMOTE ]; then
        state="up-to-date"
    elif [ $LOCAL = $BASE ]; then
        state="pull"
    elif [ $REMOTE = $BASE ]; then
        state="push"
    else
        state="diverged"
    fi

    debug "   manage_remote_repo auto status-> $state"

    if [ "$task" = "status" ]; then
        echo "$state"
        cd "$OWD"
        return
    fi

    # check action and status
    if [ "$state" = "diverged" ];then
       error "Remote repo has diverged from your local version,
                $spacer you will have to resolve the conflicts manually."
       ret_val=1
       task="diverged"

    elif [ "$state" = "up-to-date" ];then
       success "Local repo is" "$(printf "%bup to date" "$hc_topic" )" "with remote:" "$remote_repo"
       # check for uncommitted changes (aborted by user)
       state="$(git status --porcelain | indent_lines)"
       if [ -n "$state" ]; then
          warn "There are uncommitted local changes in your repo\n" "$(printf "%b$state" $red )"
       fi
       ret_val=0
       task="up-to-date"

    elif [ "$task" = "auto" ]; then
       info "Auto determined git status:" "$(printf "%b$state" "$hc_topic" )"
       task="$state"
    elif [ "$task" != "$state" ];then
        warn "A $task was requested, but a" "$(printf "%b$state" "$hc_topic" )" "is required, please resolve the conflict"
    fi



    # perform task for git
    if [ "$task" = "push" ] || [ "$task" = "pull" ];then
        confirm_task "$task" "" "$remote_repo" "$confirmed" --confvar "GIT_CONFIRMED"
        if ! [ $? -eq 0 ]; then return 1; fi

        result="$(git "$task" origin "$branch" 2>&1)"
        success_or_fail $? "$task" "$(indent_lines "$result")"
        ret_val=$?
    fi

    cd "$OWD"

    return $ret_val
}


init_local_repo (){
    local repo="$1"
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"

    confirm_task "initialize" "git for" "$repo_status repo:" "$local_repo" --confvar "GIT_CONFIRMED"
    if ! [ $? -eq 0 ]; then exit; fi

    cd "$local_repo"

    result="$(git init 2>&1)"
    success_or_error $? "" "$(indent_lines "$result")"

    result="$(git remote add origin "${remote_repo}.git" 2>&1)"
    success_or_fail $? "add" "$(indent_lines "${result:-"remote origin: ${remote_repo}.git"}")"

    install_required_repo_files "$repo"
    git_commit "$repo" "initialized by dotsys"

    cd "$OWD"
}


git_commit () {

    local repo="$1"
    local message="$2"
    shift; shift
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local result
    local user_input
    local default
    local state

    local usage="git_commit [<option>]"
    local usage_full="
        -s | --silent        Surpress output
    "
    local silent
    while [[ $# > 0 ]]; do
        case "$1" in
        -s |--silent )      silent="true" ;;
        *)  invalid_option "$1";;
        esac
        shift
    done

    cd "$local_repo"

    git add .

    # Abort if nothing to commit
    state="$(git status --porcelain | indent_lines)"
    if ! [ -n "$state" ]; then cd "$OWD";return;fi

    info "$(printf "Git Status:\n%b$state%b" $yellow $rc)"

    # default message
    default="${message:-dotsys $action}"
    if [ "$limits" ]; then default="$default $(echo "${limits[@]}" | tr '\n' ' ')";fi
    if [ "$topics" ]; then default="$default $(echo "${topics[@]}" | tr '\n' ' ')";fi


    # custom commit message
    if [ ! "$message" ] && ! [ "$silent" ]; then
        get_user_input "There are local changes in your repo.
                $spacer Would you like to commit the changes?" \
                --invalid omit --default "$default" --true omit --hint "or enter a commit message\n$spacer" -r
        if ! [ $? -eq 0 ];then
            msg "$spacer commit aborted by user"
            cd "$OWD"
            return 1
        fi
    fi

    message="${user_input:-$default}"

    #script -q /dev/null git commit -a -m "$message" 2>&1 | indent_lines
    git commit -a -m "$message" 2>&1 | indent_lines

    if ! [ "$silent" ]; then success_or_fail $? "commit" ": $message";fi
    cd "$OWD"
}


init_remote_repo () {
    local repo="$1"
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local OWD="$PWD"

    confirm_task "initialize" "remote" "repo:" "$remote_repo" --confvar "GIT_CONFIRMED"
    if ! [ $? -eq 0 ]; then return; fi



    git_commit "$repo" "initialize remote"

    # Git hub will prompt for the user password
    curl -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}" > /dev/null
    success_or_fail $? "create" "$(printf "%b$repo_status" "$hc_topic")" "remote repo" "$(printf "%b$remote_repo" "$hc_topic" )"
    if ! [ $? -eq 0 ]; then
        "$(msg "$spacer However, The local repo is ready for topics...")"

    # Push to remote
    else
        cd "$local_repo"
        git push -u origin "$branch" 2>&1 | indent_lines
        success_or_fail $? "push" "$(printf "%b$repo_status" "$hc_topic")" "repo" "$(printf "%b$remote_repo@$branch" "$hc_topic")"
    fi




    cd "$OWD"
}

checkout_branch (){
    local repo="$1"
    local branch="${2:-$branch}"
    local local_repo="$local_repo"
    local OWD="$PWD"

    debug "   checkout_branch: r:$repo b:$branch"
    if is_git "$repo"; then
        cd "$local_repo"
        # Get current branch or no branch exists
        current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        if ! [ $? -eq 0 ]; then cd "$OWD"; return; fi

        debug "   checkout_branch current=$current"

        # change branch if branch != current branch
        if [ "${branch:-$current}" != "$current" ]; then
            local result="$(git checkout "$branch")"
            success_or_error $? "check" "out $(indent_lines "$result")"
        fi
        cd "$OWD"
    else
        branch="${branch:-master}"
    fi
}

clone_remote_repo () {
    local repo="$1"
    local remote_repo="$remote_repo"
    local repo_user="${repo%/*}"
    local repo_user_dir="$(repo_dir "$repo_user")"
    local OWD="$PWD"

    # make user directory (clone makes repo directory)
    mkdir -p "$repo_user_dir"

    cd "$repo_user_dir"
    git clone "$remote_repo" --progress 2>&1 | indent_lines
    success_or_fail $? "download" "remote repo: $remote_repo"
    if ! [ $? -eq 0 ];
        then repo_status="new"
    fi
    cd "$OWD"
}


install_required_repo_files () {
    local repo="$1"
    local local_repo="$local_repo"
    local OWD="$PWD"

    cd "$local_repo"

    # add a dotsys.cfg
    if ! [ -f "dotsys.cfg" ]; then
        touch dotsys.cfg
        echo "repo:${repo}" >> "dotsys.cfg"
    fi

    # gitignore *.stub files
    if ! grep -q '\*\.stub' ".gitignore" >/dev/null 2>&1; then
        debug "adding *.stub to gitignore"
        touch .gitignore
        echo "*.stub" >> ".gitignore"
        echo "*.private" >> ".gitignore"
    fi

    cd "$OWD"
}

setup_git_config () {
    local repo="$1"
    local options
    options=("${2:-global local}")
    local template="$(builtin_topic_dir "git")/gitconfig.template"
    local repo_dir="$(repo_dir "$repo")"
    local OWD="$PWD"

    if [ "$options" = local ]; then
        confirm_task "configure" "git for" "$repo" --confvar "GIT_CONFIRMED"
        if [ $? -eq 1 ]; then return; fi
    fi

    cd "$repo_dir"

    local cfg
    local global_prefix="git"
    local local_prefix="git_${repo%/*}_${repo##*/}"
    local state_prefix

    for cfg in "${options[@]}"; do

        # state prifx for cfg
        if [ "$cfg" = "local" ]; then
            state_prefix="$local_prefix"
        else
            state_prefix="$global_prefix"
        fi

        if in_state "user" "$state_prefix"; then
            continue
        fi

        # check for global as local default
        local global_authorname="$(git config --global user.name || echo "none")"
        local global_authoremail="$(git config --global user.email || echo "none")"

        # check live config & state for value
        local authorname="$(git config --$cfg user.name || get_state_value "user" "${state_prefix}_user_name" )"
        local authoremail="$(git config --$cfg user.email || get_state_value "user" "${state_prefix}_user_email" )"

        # set default
        local default_user="${authorname:-$global_authorname}"
        local default_email="${authoremail:-$global_authoremail}"


        if [ "$cfg" = "local" ]; then
            if ! [ "$authorname" ] || ! [ "$authoremail" ]; then
                if [ "$options" = local ]; then
                    msg "$spacer global author name = $global_authorname"
                    msg "$spacer global author email = $global_authoremail"
                fi
                get_user_input "Use the global author settings for your repo?" -r
                if [ $? -eq 0 ]; then continue; fi
            fi
        fi

        if [ "$cfg" != "none" ]; then
            if ! [ "$authorname" ]; then
                user "- What is your $cfg github author name? [$default_user] : "
                read -e authorname
            fi

            if ! [ "$authoremail" ]; then
                user "- What is your $cfg github author email? [$default_email] : "
                read -e authoremail
            fi
        fi

        authorname="${authorname:-$global_authorname}"
        authoremail="${authoremail:-$global_authoremail}"

        local repo_gitconfig
        # global config & create stub
        if [ "$cfg" = "global" ]; then
            repo_gitconfig="${repo_dir}/git/gitconfig.symlink"
            local cred="$(get_credentialc_helper)"
            git config "--$cfg" credential.helper "$cred"
            success "git $cfg credential set to:" "$(printf "%b$cred" "$hc_topic")"

        # local config
        elif [ "$cfg" = "local" ]; then
            repo_gitconfig="${repo_dir}/git/gitconfig.local.symlink"
            local repo_git_dir="$(repo_dir "$repo")/.git"
            mkdir -p "$repo_git_dir"
            touch "${repo_git_dir}/config"
        fi

        # local/global configs
        if [ "$cfg" != "none" ]; then
            # set vars for immediate use & record to user state for stubs

            set_state_value "user" "${state_prefix}_user_name" "$authorname"
            git config "--$cfg" user.name "$authorname"
            success "git $cfg author set to:" "$(printf "%b$authorname" "$hc_topic" )"

            set_state_value "user" "${state_prefix}_user_email" "$authoremail"
            git config "--$cfg" user.email "$authoremail"
            success "git $cfg email set to:" "$(printf "%b$authoremail" "$hc_topic" )"

            # source users existing repo gitconfig.symlink or gitconfig.local.symlink
            git config "--$cfg" include.path "$repo_gitconfig"
            success "git $cfg include set to:" "$(printf "%b$repo_gitconfig" "$hc_topic")"

            # create stub file
            if [ "$cfg" = "global" ]; then
                create_user_stub "git" "gitconfig"
            fi
        fi

        if [ "$cfg" = "local" ]; then
            success "A local .gitconfig has been created for $repo"
        else
            success "A global .gitconfig has been created for $authorname"
        fi
    done

    cd "$OWD"
}

has_remote_repo (){
    local repo="${1:-$repo}"
    local remote_repo="$remote_repo"
    local silent="$2"
    local state

    state="$(curl -Ls --head --silent "${remote_repo}" | head -n 1)"
    #wget -q "${remote}.git" --no-check-certificate -O - > /dev/null

    debug "curl result=$state"

    local ret=1
    if echo "$state" | grep "[23].." > /dev/null 2>&1; then
        ret=0
        if [ "$silent" ];then  return $ret;fi
        success "remote found: $state
         $spacer -> $remote_repo"

    elif echo "$state" | grep "[4].." > /dev/null 2>&1; then
        ret=1
        if [ "$silent" ];then  return $ret;fi
        success "remote not found: $state
         $spacer -> $remote_repo"

    elif echo "$state" | grep "[5].." > /dev/null 2>&1; then
        ret=2
        if [ "$silent" ];then  return $ret;fi
        error "connection failed: $state
       $spacer -> $remote_repo"
    fi

    return $ret
}

is_git (){
    local repo="${1:-$repo}"
    local repo_dir="$(repo_dir "$repo")"
    local OWD="$PWD"
    local state=1
    if ! [ -d "$repo_dir" ] || ! [ -d "${repo_dir}/.git" ]; then return 1;fi
    cd "$repo_dir"
    git rev-parse --git-dir > /dev/null 2>&1
    local state=$?
    cd "$OWD"
    return $state
}


copy_topics_to_repo () {

    local repo="$1"
    local root_dir="$(dotfiles_dir)"
    local repo_dir="$(repo_dir "$repo")"
    local confirmed
    local mode


    local question="$(printf "Would you like to search for existing topics in
                    $spacer directory: %b%s%b
                    $spacer %b(You will confirm each topic before import)%b" \
                    "$hc_topic" "$root_dir" $rc \
                    $c_help $rc )"

    local hint="$(printf "\b, or %bpath/to/directory%b" $yellow $rc)"

    local error
    while true; do
        local user_input=
        get_user_input "${question}?" -h "$hint${error}" -i "omit" -c
        case "$user_input" in
            yes ) break ;;
            no  ) return ;;
            *   ) if [ -d "$user_input" ]; then
                    root_dir="$user_input"
                    break
                  else
                    error=" Directory not found, try again"
                  fi
        esac
    done

    local found_dirs=( $(get_dir_list "$root_dir") )

    #IFS=$' \t\n'

    # filter and list found topics
    local i
    for i in "${!found_dirs[@]}"; do
        local topic="${found_dirs[$i]}"
        local files="$(find "$root_dir/$topic" -maxdepth 1 -type f)"
        #local is_repo="$(find "$dir/$topic" -maxdepth 3 -type f -name "*dotsys.cfg")"

        debug "$topic=${repo%/*}"

        # not $repo user and must have files
        if [ "$topic" = "${repo%/*}" ] || ! [ "$files" ]; then
            unset found_dirs[$i]
            continue
        fi

        # and must contain at lest one recognised file type in topic root
        local f
        local found_file
        for f in $files; do
            debug "file = $f"
            if [[ "$f" =~ (.*\.symlink|.*\.sh|.*\.zsh) ]]; then
                debug "found = $f"
                found_file="true"
                break
            fi
        done

        if ! [ "$found_file" ]; then
            unset found_dirs[$i]
            continue
        fi
    done

    # Importable found
    if [ "${found_dirs[*]}" ]; then
        task "Import topics found in directory:" "$(printf "\n$spacer %b$root_dir:" "$hc_topic")"
        msg "$(echo "${found_dirs[@]}" | indent_list)"
    # noting to import
    else
       info "Importable topics not found in directory:" "$(printf "\n$spacer $root_dir:" "$hc_topic")"
       return
    fi

    question="The above possible topics were found. How would
      $spacer you like the topics you select imported"

    get_user_input "${question}?" -t copy -f move -c
    if [ $? -eq 0 ]; then mode=copy; else mode=move; fi


    local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"
    # Confirm each file to move/copy
    local topic
    for topic in ${found_dirs[@]}; do
        confirm_task "$mode" "" "$topic" "$(printf "%bfrom:" "$hc_topic" ) $root_dir" "$(printf "%bto:" "$hc_topic" ) $repo_dir" --confvar "COPY_TOPIC_CONFIRMED"
        if [ $? -eq 0 ]; then
            clear_lines "" 2 #clear task confirm
            #local topic="${t##*/}"
            printf "$dark_gray"
            if [ "$mode" = "copy" ]; then
                cp -LRai "${root_dir}/$topic" "${repo_dir}/$topic"
            elif [ "$mode" = "move" ]; then
                mv -i "${root_dir}/$topic" "${repo_dir}/$topic"
            fi
            printf "$rc"

            success_or_fail $? "$mode" "$(printf "%b$topic%b -> %b$repo_dir%b" "$hc_topic" $rc "$hc_topic" $rc)"

        else
          clear_lines "" 2 # clear two lines of
        fi
    done

}

confirm_make_primary_repo (){
    local repo="$1"
    # if repo is same as state, bypass check
    if [ "$(state_primary_repo)" = "$repo" ]; then return ; fi

    get_user_input "$(printf "Would you like to make this your primary repo:\n$spacer %b$(repo_dir "$repo")%b" "$hc_topic" $rc)" --required
    if [ $? -eq 0 ]; then
        state_primary_repo "$repo"
        success "New primary repo:" "$(printf "%b$repo" "$hc_topic")"
    fi
}

# Determine if the repo is present in any state file
repo_in_use () {
    local repo="${1:-dotsys/dotsys}"
    debug "repo in use: $repo"
    local states="$(get_state_list)"
    local s
    for s in $states; do
        if in_state "$s" "!repo" "$repo"; then
        return 0; fi
    done
    return 1
}

# sets / gets primary repo value
state_primary_repo(){
  local repo="$1"
  local key="primary_repo"

  if [ "$repo" ]; then
    set_state_value "user" "$key" "$repo"
  else
    echo "$(get_state_value "user" "$key")"
  fi
}