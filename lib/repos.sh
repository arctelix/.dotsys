#!/usr/bin/env bash

manage_repo (){


    local usage="manage_repo <action> <repo> [<branch> <options>]"
    local usage_full="Installs and uninstalls dotsys.
    --force            Force the repo management
    --silent | -s      Manage repo without confirmations or messages
    "
    local action
    local repo
    local force
    local confirmed

    if [ "${TOPIC_CONFIRMED:-"$GLOBAL_CONFIRMED"}" ]; then
        confirmed="--confirmed"
    fi

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )       force="$1" ;;
        --confirmed )   confirmed="--confirmed" ;;
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
        repo_status="local directory"
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
                    confirmed=""
                fi
            # Abort on repo in use
            elif repo_in_use "$repo"; then
               error "$(printf "The repo $repo is in use and can not be uninstalled yet.
                        $spacer You must first run 'dotsys uninstall from $repo'")"
               exit

            # ok to remove unused repo without confirm
            else
               task "$(printf "Uninstall $repo_status unused repo %b$repo%b" $green $cyan)"
               confirmed="true"
            fi

        # ALL EXCEPT UNINSTALL

        else

            # Check for git and convert to install
            if ! [ -d "${local_repo}/.git" ];then
                warn "$(printf "The local repo %b$repo$b is not initialized for git." $green $rc)"
                action="install"
            fi
        fi

    fi

    # ABORT: ACTION ALREADY DONE (we do this after the checks to make sure status has not changed)
    if [ "$complete" ]; then
        # Only show the complete message when we are installing a repo!
        if in_limits "repo" -r; then
            task "$(printf "Already ${action%e}ed: %b$repo%b" $green $cyan)"
        fi
        return
    # CONFIRM
    else
        confirm_task "$action" "" "$repo_status repo:" "$local_repo" --confvar "GLOBAL_CONFIRMED"
        if ! [ $? -eq 0 ]; then return; fi
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
        elif [ "$repo_status" != "local directory" ];then
            mkdir -p "$local_repo"
            if ! [ $? -eq 0 ]; then error "Local repo $local_repo could not be created"; exit; fi
        fi

        # GIT CONFIG (after remote: need existing configs)
        if ! in_state "user" "git_user_name"; then
            setup_git_config "$repo"
        fi

        # make sure repo is git!
        if ! is_git; then
            init_local_repo "$repo"
            if ! [ $? -eq 0 ]; then exit; fi
        fi

        # Check EXISTING/INSTALLED status
        if ! is_dotsys_repo && [ "$repo_status" != "remote" ] && [ "$repo_status" != "new" ];then
            debug "   local directory/installed check for remote"
            if has_remote_repo "$repo"; then
                manage_remote_repo "$repo" auto
                if ! [ $? -eq 0 ]; then exit; fi
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

            # preview repo option
            confirm_task "preview" "repo" "${repo}" "-> ${repo}/.dotsys-default.cfg"
            if [ "$?" -eq 0 ]; then
                create_config_yaml "$repo"
                if [ $? -eq 0 ]; then
                    get_user_input "Would you like to install this repo?" -r
                    if ! [ $? -eq 0 ]; then exit; fi
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
        create_config_yaml "$repo"
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
                get_user_input "Would you like to delete local repo $repo?" -d no -r
                if [ $? -eq 0 ]; then
                    rm -rf "$local_repo"
                fi
            fi
        fi
    fi

    # Success / fail message
    success_or_fail $action_status "$action" "$(printf "$repo_status repo %b$local_repo%b" $green $rc)"
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
    local status

    while [[ $# > 0 ]]; do
    case "$1" in
      auto )        task="$1" ;;
      push )        task="$1" ;;
      pull )        task="$1" ;;
      status )      task="$1" ;;
      --message )   message="$1" ;;
      --confirmed )   confirmed="--confirmed" ;;
      * ) invalid_option;;
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
    if ! $(git rev-parse @{u} > /dev/null 2>&1); then
        debug "   manage_remote_repo: git rev-parse failed attempting git checkout $branch"

        # Make sure branch is checked out (sets origin automatically)
        result="$(git checkout $branch 2> /dev/null)"
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
        status="up-to-date"
    elif [ $LOCAL = $BASE ]; then
        status="pull"
    elif [ $REMOTE = $BASE ]; then
        status="push"
    else
        status="diverged"
    fi

    debug "   manage_remote_repo auto status-> $status"

    if [ "$task" = "status" ]; then
        echo "$status"
        cd "$OWD"
        return
    fi

    # check action and status
    if [ "$status" = "diverged" ];then
       error "$(printf "Remote repo has diverged from your local version,
                $spacer you will have to resolve the conflicts manually.")"
       ret_val=1
       task="diverged"

    elif [ "$status" = "up-to-date" ];then
       success "$(printf "%bLocal repo is up to date with remote:%b $remote_repo" $green $rc)"
       # check for uncommitted changes (aborted by user)
       local status="$(git status --porcelain | indent_lines)"
       if [ -n "$status" ]; then
          warn "$(printf "There are uncommitted local changes in your repo\n%b$status%b" $red $rc)"
       fi
       ret_val=0
       task="up-to-date"

    elif [ "$task" = "auto" ]; then
       info "Auto determined git status: $status"
       task="$status"
    elif [ "$task" != "$status" ];then
        warn "A $task was requested, but a $status is required, please resolve the conflict"
    fi



    # perform task for git
    if [ "$task" = "push" ] || [ "$task" = "pull" ];then
        confirm_task "$task" "" "$remote_repo" "$confirmed"
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

    confirm_task "initialize" "git for" "$repo_status repo:" "$local_repo"
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
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local result
    local user_input
    local default

    usage="git_commit [<option>]"
    usage_full="
        -s | --silent        Surpress output
    "
    local silent
    while [[ $# > 0 ]]; do
        case "$1" in
        -s |--silent )      silent="true" ;;
        *)  invalid_option ;;
        esac
        shift
    done

    cd "$local_repo"

    git add .

    # Abort if nothing to commit
    local status="$(git status --porcelain | indent_lines)"
    if ! [ -n "$status" ]; then cd "$OWD";return;fi

    info "$(printf "Git Status:\n%b$status%b" $yellow $rc)"

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
            printf "$spacer %bcommit aborted by user%b\n" $yellow $rc
            return 0
            cd "$OWD"
        fi
    fi

    message="${user_input:-$default}"

    script -q /dev/null git commit -a -m "$message" 2>&1 | indent_lines

    if ! [ "$silent" ]; then success_or_fail $? "commit" ": $message";fi
    cd "$OWD"
}


init_remote_repo () {
    local repo="$1"
    local local_repo="$local_repo"
    local remote_repo="$remote_repo"
    local OWD="$PWD"

    confirm_task "initialize" "remote" "repo:" "$remote_repo"
    if ! [ $? -eq 0 ]; then return; fi



    git_commit "$repo" "initialize remote"

    # Git hub will prompt for the user password
    local resp=`curl -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"`
    success_or_fail $? "create" "$(printf "%b$repo_status%b remote repo %b$remote_repo%b" $green $rc $green $rc)" \
                    "$(msg "$spacer However, The local repo is ready for topics...")"

    cd "$local_repo"
    git push -u origin "$branch"
    success_or_fail $? "push" "$(printf "%b$repo_status%b repo %b$remote_repo @ $branch%b" $green $rc $green $rc)" \
                    "$(msg "$spacer However, The local repo is ready for topics...")"
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
    local repo_user="$(cap_first "${repo%/*}")"
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
    local template="$(builtin_topic_dir "git")/gitconfig.template"
    local repo_dir="$(repo_dir "$repo")"
    local OWD="$PWD"

    confirm_task "configure" "git for" "$repo"

    if [ $? -eq 1 ]; then return; fi

    cd "$repo_dir"

    local cfg

    for cfg in "global" "local"; do

        # state prifx for cfg
        local state_prefix="git"
        if [ "$cfg" = "local" ]; then
            state_prefix+="_$cfg"
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
                get_user_input "Use the global settings for your repo?"
                if [ $? -eq 0 ]; then
                    continue
                fi
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
            local cred="$(get_credential_helper)"
            git config "--$cfg" credential.helper "$cred"
            success "$(printf "git %b$cfg credential%b set to: %b$cred%b" $green $rc $green $rc)"

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
            success "$(printf "git %b$cfg author%b set to: %b$authorname%b" $green $rc $green $rc)"

            set_state_value "user" "${state_prefix}_user_email" "$authoremail"
            git config "--$cfg" user.email "$authoremail"
            success "$(printf "git %b$cfg email%b set to: %b$authoremail%b" $green $rc $green $rc)"

            # source users existing repo gitconfig.symlink or gitconfig.local.symlink
            git config "--$cfg" include.path "$repo_gitconfig"
            success "$(printf "git %b$cfg include%b set to: %b$repo_gitconfig%b" $green $rc $green $rc)"

            # create stub file
            if [ "$cfg" = "global" ]; then
                create_user_stub "git" "gitconfig"
            fi
        fi


    done

    cd "$OWD"

    success "Git has been configured for $repo"

}

has_remote_repo (){
    local repo="${1:-$repo}"
    local remote_repo="$remote_repo"
    local silent="$2"
    local status

    status="$(curl -Ls --head --silent "${remote_repo}" | head -n 1)"
    #wget -q "${remote}.git" --no-check-certificate -O - > /dev/null

    debug "curl result=$status"

    local ret=1
    if echo "$status" | grep "[23].." > /dev/null 2>&1; then
        ret=0
        if [ "$silent" ];then  return $ret;fi
        success "remote found: $status
         $spacer -> $remote_repo"

    elif echo "$status" | grep "[4].." > /dev/null 2>&1; then
        ret=1
        if [ "$silent" ];then  return $ret;fi
        success "remote not found: $status
         $spacer -> $remote_repo"

    elif echo "$status" | grep "[5].." > /dev/null 2>&1; then
        ret=2
        if [ "$silent" ];then  return $ret;fi
        error "connection failed: $status
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


    local question="$(printf "Would you like to %badd%b existing topics from %b%s%b
                    $spacer %b(You will be asked to confirm each topic before import)%b" \
                    $green $rc \
                    $green "$root_dir" $rc \
                    $dark_gray $rc )"

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

    local found_dirs=($(get_dir_list "$root_dir"))

    # filter and list found topics
    if [ "$found_dirs" ]; then
        task "$(printf "Import topics found in %b$root_dir%b:" $green $rc)"
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
            # list topic
            msg "$spacer - $topic"
        done

    # noting to import
    else
       task "$(printf "Import topics not found in %b$root_dir%b:" $green $rc)"
       return
    fi

    question="$(printf "The above possible topics were found. How would
                $spacer you like the topics you select imported" $yellow $rc $yellow $rc $yellow $rc)"

    get_user_input "${question}?" -t move -f copy -f copy -c
    if [ $? -eq 0 ]; then mode=move; else mode=copy; fi


    local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"
    # Confirm each file to move/copy
    local topic
    for topic in ${found_dirs[@]}; do
        confirm_task "$mode" "" "$topic" "$(printf "%bfrom:%b $root_dir \n$spacer %bto:%b $repo_dir" $green $rc $green $rc)"
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

            success_or_fail $? "$mode" "$(printf "%b$topic%b -> %b$repo_dir%b" $green $rc $green $rc)"

        else
          clear_lines "" 2 # clear two lines of
        fi
    done

}

confirm_make_primary_repo (){
    local repo="$1"
    # if repo is same as state, bypass check
    if [ "$(state_primary_repo)" = "$repo" ]; then return ; fi

    get_user_input "$(printf "Would you like to make this your primary repo:\n$spacer %b$(repo_dir "$repo")%b" $green $rc)" --required
    if [ $? -eq 0 ]; then
        state_primary_repo "$repo"
        set_user_vars "$repo"
        success "$(printf "New primary repo: %b$repo%b" $green $rc)"
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