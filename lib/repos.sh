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

    if [ "$action" = "update" ];then
        return
    fi

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
        error "Git was not found on your system, run $(code "dotsys install dotsys" )"
        exit
    fi

    local installed
    local repo_status
    local has_remote

    if get_remote_status;then has_remote=true ;fi

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
        if [ "$has_remote" ]; then
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

        if [ "$repo_status" = "missing" ] && [ "$has_remote" ]; then
            repo_status="remote"
        fi

        # REMOTE: Clone existing repo
        if [ "$repo_status" = "remote" ];then
            clone_remote_repo "$repo"
        fi

        # Confirm dir and required files exist (after remote or clone will fail!)
        install_required_repo_files "$repo"

        # GIT CONFIG (after remote: need existing configs)
        setup_git_config "$repo" "local"

        # make sure repo is git!
        if ! is_git; then
            init_local_repo "$repo"
            if ! [ $? -eq 0 ]; then
                error "Could not initialize local repo."; exit
            fi
        fi

        # Make sure repo is up to date
        if [ "$has_remote" ]; then
            manage_remote_repo "$repo" auto

        # NEW: initialize remote repo
        else
            init_remote_repo "$repo"
            msg "$spacer Don't forget to add topics to your new repo..."
        fi

        # MAKE PRIMARY if not offer some options
        debug "check primary repo: $(state_primary_repo) != current $repo"

        if ! is_dotsys_repo && [ "$(state_primary_repo)" != "$repo" ]; then

            # preview repo and confirm install
            if [ "$repo_status" != "new" ];then

                confirm_task "preview" "repo" "config ${repo}" "-> ${repo}/.dotsys-default.cfg" --confvar ""
                if ! [ $? -eq 0 ]; then return; fi

                create_config_yaml "$repo" | indent_lines
                get_user_input "Would you like to install this repo?" -r
                if ! [ $? -eq 0 ]; then
                    msg "Repo installation aborted by user"; exit
                fi
            fi

            confirm_make_primary_repo "$repo"
        fi

        state_install "$state_file" "$state_key" "$repo"
        action_status=$?

    elif [ "$action" = "upgrade" ]; then
        manage_remote_repo "$repo" auto --confirmed
        action_status=$?

    elif [ "$action" = "freeze" ]; then
        # list installed repos
        if ! is_dotsys_repo;then
            create_config_yaml "$repo" | indent_lines
        fi
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
        if [ -d "$local_repo" ] && [ "$has_remote" ]; then
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
    local init_required
    local result

    if ! [ "$has_remote" ] && ! get_remote_status; then
        warn "There is no remote for $repo;
        $spacer to add a remote use the command:
        $spacer $(code "dotsys install $repo")"
        return
    fi

    debug "-- manage_remote_repo: $task b:$branch"
    debug "-- manage_remote_repo local_repo: $local_repo"
    debug "-- manage_remote_repo remote_repo: $remote_repo"

    cd "$local_repo"

    # http://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
    # must run 'git fetch' or 'git remote update' first

    # Update from remote
    debug "   manage_remote_repo: git remote update"
    result="$(git remote update 2>&1)"
    ret_val=$?

    # Make sure upstream is configured
    if ! [ $ret_val -eq 0 ] || ! [ "$result" ]; then
        init_required="remote improperly configured"

    # Make sure we can resolve remote branch
    elif ! git rev-parse HEAD > /dev/null 2>&1; then
        init_required="could not determine head status"

    elif ! [ "$task" = "status" ];then
        info "$(indent_lines -f "$result")"
    fi

    # Attempt to reinitialize local repo to fix problems
    if [ "$init_required" ];then
        if ! [ "$task" = "status" ];then
            warn "$init_required
          $spacer Re-initializing the local repo could fix the problem"
            init_local_repo "$repo"
            ret_val=$?
        else
            error "$init_required
            \r $(indent_lines "$result")"
            exit
        fi
    fi

    # make sure everything is committed or we'll get a false reading
    git_commit "$repo" "$message"
    if ! [ $? -eq 0 ];then
        return 0
    fi

    cd "$local_repo"
    # Determine git status
    debug "   manage_remote_repo: check status local"
    local LOCAL=$(git rev-parse HEAD)
    debug "   manage_remote_repo: check status remote"
    local REMOTE=$(git rev-parse @{u})
    debug "   manage_remote_repo: check status base"
    local BASE=$(git merge-base HEAD @{u})
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
       success "Local repo is" "up to date" "with remote:" "\n$spacer $remote_repo"
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
        warn "A $task was requested, but a" "$state" "is required,
        \n$spacer to update your repo run $(code "dotsys upgrade $repo")"
        task="abort"
    fi



    # perform task for git
    if [ "$task" = "push" ] || [ "$task" = "pull" ];then
        confirm_task "$task" "" "$remote_repo" "$confirmed" --confvar "GIT_CONFIRMED"
        if ! [ $? -eq 0 ]; then return 1; fi

        result="$(git "$task" origin "$branch" 2>&1)"
        success_or_fail $? "$task" "$(indent_lines -f "$result")"
        ret_val=$?
    fi

    cd "$OWD"

    return $ret_val
}


init_local_repo (){
    local repo="$1"
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local result
    local rv

    confirm_task "initialize" "git for" "$repo_status repo:" "$local_repo" --confvar "GIT_CONFIRMED"
    if ! [ $? -eq 0 ]; then exit; fi

    cd "$local_repo"

    result="$(git init 2>&1)"
    success_or_error $? "" "$result"

    # Check existing origin = remote
    if [ "$(git remote get-url origin 2>/dev/null)" != "${remote_repo}.git" ];then
        git remote remove origin >/dev/null 2>&1
        result="$(git remote add origin "${remote_repo}.git" 2>/dev/null)"
        success_or_fail $? "" "$(indent_lines -f "${result:-Add remote origin: ${remote_repo}.git}")"
    fi

    # Sync local with remote
    if [ "$has_remote" ];then
        git add .
        result="$(git remote update 2>&1)"
        success_or_fail $? "" "$(indent_lines -f "$result")"
        result="$(git checkout "$branch" 2>&1)"
        success_or_fail $? "" "$(indent_lines -f "$result")"

    # Make inital commit
    else
        git_commit "$repo" "initialized by dotsys"
    fi

    # make sure everything is ok
    #git rev-parse HEAD >/dev/null 2>&1
    #success_or_error $? "initialize" "git for $local_repo"

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
    local git_status

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
    git_status="$(git status --porcelain | indent_lines )"
    if ! [ -n "$git_status" ]; then cd "$OWD";return 0;fi

    info "$(printf "Git Status:\n%b$git_status%b" $yellow $rc)"

    # default message
    default="${message:-dotsys $action}"
    if [ "$limits" ]; then default="$default $(echo "${limits[@]}" | tr '\n' ' ')";fi
    if [ "$topics" ]; then default="$default $(echo "${topics[@]}" | tr '\n' ' ')";fi


    # custom commit message
    if [ ! "$message" ] && [ ! "$silent" ]; then
        get_user_input "There are local changes in your repo.
                $spacer Would you like to commit the changes?" \
                --invalid omit --default "$default" --true omit --hint "or enter a commit message\n$spacer" -r
        if ! [ $? -eq 0 ];then
            info "commit aborted by user"
            cd "$OWD"
            return 1
        fi
    fi

    info "Committing changes : $message"

    message="${user_input:-$default}"

    #script -q /dev/null git commit -a -m "$message" 2>&1 | indent_lines
    git commit -a -m "$message" 2>&1 | indent_lines
    if ! [ "$silent" ]; then success_or_fail $? "commit" "changes : $message";fi
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

    # Create remote repo (Git hub will prompt for the user password)
    create_github_repo "$repo_user/$repo_name" > /dev/null
    success_or_fail $? "create" "$repo_status" "remote repo" "$remote_repo"

    # Create remote error
    if ! [ $? -eq 0 ]; then
        "$(msg "$spacer However, The local repo is ready for topics...")"

    # Push local to remote
    else
        cd "$local_repo"
        git push -u origin "$branch" 2>&1 | indent_lines
        success_or_fail $? "push" "$repo_status" "repo" "$remote_repo@$branch"
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
            local result="$(git checkout "$branch" )"
            success_or_error $? "check" "out $(indent_lines -f "$result")"
        fi
        cd "$OWD"
    fi
}

clone_remote_repo () {
    local repo="$1"
    local remote_repo="$remote_repo"
    local repo_dir="$(repo_dir "$repo")"
    local repo_parent_dir="${repo_dir%/*}"
    local OWD="$PWD"

    # make parrent directory (clone makes repo directory)
    mkdir -p "$repo_parent_dir"

    cd "$repo_parent_dir"
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

    # make sure local repo directory exists
    mkdir -p "$local_repo"
    if ! [ $? -eq 0 ]; then
        error "Local repo $local_repo could not be created"
        exit
    fi

    cd "$local_repo"

    # add a dotsys.cfg
    if ! [ -f "dotsys.cfg" ]; then
        touch dotsys.cfg
        echo "repo:${repo}" >> "dotsys.cfg"
    fi

    # Add .git ignore
    if ! [ -f ".gitignore" ];then
        touch .gitignore
    fi

    # Add ignore patterns
    if ! grep -q '\*\.private' ".gitignore" >/dev/null 2>&1; then
        echo "*.private" >> ".gitignore"
    fi

    if ! grep -q '\*\.dslog' ".gitignore" >/dev/null 2>&1; then
        echo "*.dslog" >> ".gitignore"
    fi

    cd "$OWD"
}

setup_git_config () {

    # looks for
    local repo="$1"
    local options
    options=(global local)
    local template="$(builtin_topic_dir "git")/gitconfig.template"
    local repo_dir="$(repo_dir "$repo")"
    local OWD="$PWD"
    local repo_gitconfig

    if [ "$options" = local ]; then
        confirm_task "configure" "git for" "$repo" --confvar "GIT_CONFIRMED"
        if [ $? -eq 1 ]; then return; fi
    fi

    cd "$repo_dir"

    local cfg
    local global_prefix=
    local local_prefix=
    local state_prefix
    local include

    for cfg in "${options[@]}"; do

        # state prifx for cfg
        if [ "$cfg" = "local" ]; then
            state_prefix="$(echo "git_${repo%/*}_${repo##*/}" | tr '-' '_')"
            repo_gitconfig="${repo_dir}/git/gitconfig.local"

            # Create local config file if not there
            mkdir -p "${repo_dir}/.git"
            touch "${repo_dir}/.git/config"

        else
            state_prefix="git_global"
            repo_gitconfig="${repo_dir}/git/gitconfig.symlink"
        fi

        # source repo gitconfig.symlink or gitconfig.local
        if [ -f "$repo_gitconfig" ];then

            if [ "$repo_gitconfig" != "$(git config "--$cfg" include.path)" ];then
                git config "--$cfg" include.path "$repo_gitconfig"
                success "$cfg git config include set:" "$repo_gitconfig"
            fi
            include="--includes"
        fi

         # state values
        local state_authorname="$(get_state_value "user" "${state_prefix}_author_name")"
        local state_authoremail="$(get_state_value "user" "${state_prefix}_author_email")"

        # check current config & state for value
        local authorname="$(git config --$cfg $include user.name || echo "$state_authorname" )"
        local authoremail="$(git config --$cfg $include user.email ||  echo "$state_authoremail" )"

        local global_authorname="$(git config --global $include user.name)"
        local global_authoremail="$(git config --global $include user.email)"
        local update

        local default_user="${authorname:-$global_authorname}"
        local default_email="${authoremail:-$global_authoremail}"

        msg "$spacer $cfg author name = $authorname"
        msg "$spacer $cfg author email = $authoremail"

        # Confirm git settings

        if [ "$authoremail" ] && [ "$authorname" ]; then
            get_user_input "Use the above $cfg git settings?" -r
            if ! [ $? -eq 0 ]; then
                update=true
            fi
        fi

        if [ "$cfg" = "local" ] && [ "$update" ] && [[ "$global_authorname" && "$global_authoremail" ]]; then

            msg "$spacer global author name = $global_authorname"
            msg "$spacer global author email = $global_authoremail"
            get_user_input "Use the global author settings for $repo?" -r
            if [ $? -eq 0 ]; then
                authorname="$global_authorname"
                authoremail="$global_authoremail"
                update=''
            fi
        fi

        # Set new values

        if ! [ "$authorname" ] || [ "$update" ]; then
            user "- What is your $cfg github author name? [$default_user] : "
            read -e authorname
        fi

        if ! [ "$authoremail" ] || [ "$update" ]; then
            user "- What is your $cfg github author email? [$default_email] : "
            read -e authoremail
        fi

        authorname="${authorname:-$default_user}"
        authoremail="${authoremail:-$default_email}"

        # Set credential helper for global only
        if [ "$cfg" = "global" ]; then
            local values_script="$(get_user_or_builtin_file "git" "gitconfig.vars")"
            local cred="$(execute_script_func "$values_script" "credential_helper")"
            git config "--$cfg" credential.helper "$cred"
            success "git $cfg credential set to:" "$cred"
        fi

        if [ "$authorname" != "$state_authorname" ];then
            set_state_value "user" "${state_prefix}_author_name" "$authorname"
            git config "--$cfg" $include user.name "$authorname"
            success "git $cfg author set to:" "$authorname"
        fi

        if [ "$authoremail" != "$state_authoremail" ];then
            set_state_value "user" "${state_prefix}_author_email" "$authoremail"
            git config "--$cfg" $include user.email "$authoremail"
            success "git $cfg email set to:" "$authoremail"
        fi

    done

    cd "$OWD"
}

get_remote_status (){

    local remote_repo="${1:-$remote_repo}"
    local silent="$2"
    local state

    state="$(curl -Ls --head "${remote_repo}" | head -n 1)"
    #wget -q "${remote}.git" --no-check-certificate -O - > /dev/null

    debug "get_remote_status curl result=$state"

    local ret=1
    if echo "$state" | grep "[23].." > /dev/null 2>&1; then
        ret=0
        if [ "$silent" ];then  return $ret;fi
        success "remote found: $state
         $spacer -> $remote_repo"

    elif echo "$state" | grep "[4].." > /dev/null 2>&1; then
        ret=1
        if [ "$silent" ];then  return $ret;fi
        success "remote does not exist: $state
         $spacer -> $remote_repo"

    else
        ret=2
        if [ "$silent" ];then  return $ret;fi
        error "connection failed: ${state:-Check your internet connection}
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

create_github_repo () {
    # parse user/repo
    local repo_user="${1%/*}"
    local repo_name="${1#*/}"
    curl -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"
}

get_github_archive () {
    # parse user/repo
    local repo_user="${1%/*}"
    local repo_name="${1#*/}"
    local version="${2:-master}"
    curl -L https://github.com/$repo_user/$repo_name/archive/$version.tar.gz | tar xv
}

