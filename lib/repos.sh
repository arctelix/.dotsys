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

    # separate branch from user/repo/branch
    local branch="master"
    split_repo_branch

    debug "-- manage_repo: received  a:$action r:$repo b:$branch $force"

    local github_repo="https://github.com/$repo"
    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"

    local repo_user="$(cap_first ${repo%/*})"
    local repo_name="${repo#*/}"
    local state_key="installed_repo"

    debug "   manage_repo: final ->  a:$action r:$repo lr:$local_repo b:$branch $force"

    # make sure git is installed
    if ! cmd_exists git;then
        dotsys install git --recursive
    fi

    checkout_branch "$repo" "$branch"

    local installed=
    local repo_status=

    # determine repo status
    if is_installed "dotsys" "$state_key" "$repo"; then
        installed="true"
        if [ -d "$local_repo" ]; then
            repo_status="installed"
        else
            repo_status="missing"
        fi
    # existing uninstalled local repo
    elif [ -d "$local_repo" ]; then
        info "Found uninstalled existing directory: $local_repo"
        repo_status="existing"
    else
        # check for remote
        info "Checking for specified remote 1 $github_repo"
        wget -q "${github_repo}.git" --no-check-certificate -O - > /dev/null
        # remote repo found
        if [ "$?" -eq 0 ]; then
            info "Found uninstalled remote repo: $github_repo"
            repo_status="remote"
        # no remote repo or directory
        else
            info "A new repo has been specified: $local_repo"
            repo_status="new"
        fi
    fi

    debug "   manage_repo status: $repo_status"

    # Check for action already complete (we do this first in case of status changes in checks)
    if ! [ "$force" ]; then
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
               task "$(printf "Uninstall $repo_status unused repo %b$repo%b" $green $blue)"
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

    # ABORT: ACTION ALREDY DONE (we do this after the checks to make sure status has not changed)
    if [ "$complete" ]; then
        task "$(printf "Already ${action%e}ed: %b$repo%b" $green $blue)"
        return
    # CONFIRM
    elif ! [ "$confirmed" ]; then
        confirm_task "$action" "$repo_status repo: \n$spacer $local_repo"
        if ! [ $? -eq 0 ]; then return; fi
    fi


    local action_status=1

    # ACTION INSTALL
    if [ "$action" = "install" ]; then

        # REMOTE: Clone existing repo
        if [ "$repo_status" = "remote" ];then
            clone_remote_repo "$repo"

        # create full repo directory (after remote or clone will fail)
        elif [ "$repo_status" != "existing" ];then
            mkdir -p "$local_repo"
            if ! [ $? -eq 0 ]; then error "Local repo $local_repo could not be created"; exit; fi
        fi

        # GIT CONFIG (after remote so we have repo downloaded for config)
        setup_git_config "$repo"

        # make sure repo is git!
        if ! is_git; then
            inint_local_repo "$repo"
        fi

        # EXISTING/INSTALLED check for remote
        if [ "$repo_status" = "existing" ] || [ "$repo_status" = "installed" ];then
            info "Checking $repo_status repo for remote $github_repo"
            wget -q "${github_repo}.git" --no-check-certificate -O - > /dev/null
            if [ $? -eq 0 ]; then
                manage_remote_repo "$repo" auto
                if ! [ $? -eq 0 ]; then
                    exit
                fi
            else
                repo_status="new"
            fi
        fi

        # add a .dotsys.cfg
        if ! [ -f ".dotsys.cfg" ]; then
            touch .dotsys.cfg
            echo "repo:${repo}" >> ".dotsys.cfg"
        fi

        # NEW: initialize remote repo
        if [ "$repo_status" = "new" ];then

            init_remote_repo "$repo"

            msg "$spacer Don't forget to add topics to your new repo..."
            copy_topics_to_repo "$repo"
        fi

        state_install "dotsys" "$state_key" "$repo"
        action_status=$?

        # MAKE PRIMARY if not offer some options
        if [ "$(state_primary_repo)" != "$repo" ]; then

            confirm_make_primary_repo "$repo"

            # create dotsys-export.yaml
            confirm_task "freeze" "repo" "to ${repo}/.dotsys-default.cfg"
            if [ "$?" -eq 0 ]; then
                create_config_yaml "$repo"
            fi
            msg "$spacer HINT: Freeze any time with 'dotsys freeze user/repo_name'"
        fi

    elif [ "$action" = "update" ];then
        # this should pull if required but not push!
        manage_remote_repo "$repo" pull --confirmed
        action_status=$?

    elif [ "$action" = "upgrade" ]; then
        manage_remote_repo "$repo" auto --confirmed
        action_status=$?

    elif [ "$action" = "freeze" ]; then
        # list installed repos
        echo "repo $action not implemented"
        action_status=$?

    elif [ "$action" = "uninstall" ]; then
        if repo_in_use "$repo" && ! [ "$force" ]; then
            # in use uninstall not permitted
            fail "$(printf "The repo $repo is in use and can not be uninstalled yet.
                    $spacer You must first run 'dotsys uninstall from $repo'")"
            exit
        fi

        # remove from state (check for installed and user default)
        state_uninstall "dotsys" "user_repo" "$repo"
        state_uninstall "dotsys" "$state_key" "$repo"
        action_status=$?
        # confirm delete if repo exists
        if [ -d "$local_repo" ]; then
            manage_remote_repo "$repo" push
            # delete local repo (only if remote is pushed)
            if [ $? -eq 0 ]; then
                get_user_input "Would you like to delete local repo $repo?"
                if [ $? -eq 0 ]; then
                    rm -rf "$local_repo"
                fi
            fi
        fi
    fi

    # Success / fail message
    success_or_fail $action_status "$action" "$(printf "$repo_status repo %b$local_repo%b" $green $rc)"
    return $?
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

    local status=0
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

    debug "-- manage_remote_repo: $task b:$branch"


    local local_repo="$(repo_dir "$repo")"
    local remote_repo="https://github.com/$repo"
    local result
    local OWD="$PWD"

    if [ "$task" = "auto" ] || [ "$task" = "status" ]; then
        # http://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
        # must run 'git fetch' or 'git remote update' first

        cd "$local_repo"

        result="$(git remote update 2>&1)"
        if ! [ $? -eq 0 ]; then
            status=1
            if ! [ "$task" = "status" ]; then
                error "$(indent_lines "$result")"
            fi
        elif ! [ "$task" = "status" ]; then
            info "$(indent_lines "$result")";
        fi

        # set branch upstream to origin/branch if not already
        if ! git rev-parse @{u} > /dev/null; then
            debug "-- manage_remote_repo: set current branch upstream"
            result="$(git branch --set-upstream-to origin/$branch 2>&1)"
            success_or_fail $? "set upstream:" "$(indent_lines "$result")"
            if ! [ $? -eq 0 ]; then init_remote_repo "$repo";fi
        fi

        debug "   manage_remote_repo: check status local"
        local LOCAL=$(git rev-parse @)
        debug "   manage_remote_repo: check status remote"
        local REMOTE=$(git rev-parse @{u})
        debug "   manage_remote_repo: check status base"
        local BASE=$(git merge-base @ @{u})

        cd "$OWD"

        if [ $LOCAL = $REMOTE ]; then
            task="up-to-date"
        elif [ $LOCAL = $BASE ]; then
            task="pull"
        elif [ $REMOTE = $BASE ]; then
            task="push"
        else
            task="diverged"
        fi

        debug "   manage_remote_repo auto -> $task"
    fi

    if [ "$task" = "status" ]; then
        echo "$task"
        return
    fi

    if [ "$task" = "push" ] || [ "$task" = "pull" ];then

        confirm_task "$task"  "$remote_repo" "$confirmed"
        if ! [ $? -eq 0 ]; then return 1; fi

        cd "$local_repo"

        if [ "$task" = "push" ]; then
            # custom commit message
            if [ ! "$message" ]; then
                local user_input
                message="dotsys $action ${limits[0]} ${topics[@]:-\b}"
                get_user_input "Would you like to add a custom commit message?\n$spacer" --invalid false --default "$message"
                if [ $? -eq 0 ]; then message="$user_input"; fi
            fi
            git add .
            git commit -a -m "$message"
        fi

        # execute action
        debug "   manage_remote_repo: git $task origin $branch"
        result="$(git "$task" origin "$branch" 2>&1)"
        success_or_fail $? "$task" "$(indent_lines "$result")"
        status=$?

        cd "$OWD"

    elif [ "$task" = "diverged" ];then
       error "$(printf "Remote repo has diverged from your local version,
                $spacer you will have to resolve the conflicts manually.")"
       status=1
    elif [ "$task" = "up-to-date" ];then
       info "$(printf "%bRepo is up to date%b" $green $rc)"

    fi
    return $status

}

init_remote_repo () {
    local repo="$1"
    local local_repo="$(repo_dir "$repo")"
    local github_repo="https://github.com/$repo"
    local OWD="$PWD"

    confirm_task "initialize" "remote repo" "$github_repo"
    if ! [ $? -eq 0 ]; then return; fi

    cd "$local_repo"

    git add .
    git commit -m "initialized by dotsys"

    # Git hub will prompt for the user password
    local resp=`curl -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"`
    success_or_fail $? "create" "$(printf "%b$repo_status%b remote repo %b$github_repo%b" $green $rc $green $rc)" \
                    "$(msg "$spacer However, The local repo is ready for topics...")"

    git push -u origin "$branch"
    success_or_fail $? "initialize" "$(printf "%b$repo_status%b repo %b$github_repo%b" $green $rc $green $rc)" \
                    "$(msg "$spacer However, The local repo is ready for topics...")"



    cd "$OWD"
}

checkout_branch (){
    local repo="$1"
    local branch="${2:-$branch}"

    debug "   checkout_branch: r:$repo b:$branch"
    if is_git "$repo"; then
        local current="$(git rev-parse --abbrev-ref HEAD)"
        # change branch if branch != current branch
        if [ "${branch:-$current}" != "$current" ]; then
            local local_repo="$(repo_dir "$repo")"
            local OWD="$PWD"
            cd "$local_repo"
            local result="$(git checkout "$branch")"
            success_or_error $? "set" "$(indent_lines "$result")"
            cd "$OWD"
        fi
    else
        branch="${branch:-master}"
    fi
}

init_local_repo (){
    local repo="$1"
    local local_repo="$(repo_dir "$repo")"
    local github_repo="https://github.com/$repo"
    local OWD="$PWD"

    confirm_task "initialize" "$repo_status repo for git:\n$spacer  $local_repo"
    if ! [ $? -eq 0 ]; then exit; fi

    cd "$local_repo"

    result="$(git init 2>&1)"
    success_or_error $? "" "$(indent_lines "$result")"

    result="$(git remote add origin "$github_repo" 2>&1)"
    success_or_fail $? "Add remote origin" "$(indent_lines "$result")"

    #git remote -v
    checkout_branch "$repo" "$branch"

    cd "$OWD"
}

clone_remote_repo () {
    local repo="$1"
    local github_repo="https://github.com/$repo"
    local repo_user="$(cap_first "${repo%/*}")"
    local repo_user_dir="$(repo_dir "$repo_user")"
    local OWD="$PWD"

    # make user directory (clone makes repo directory)
    mkdir -p "$repo_user_dir"

    cd "$repo_user_dir"
    git clone "$github_repo"
    cd "$OWD"

    if ! [ $? -eq 0 ]; then fail "Could not fetch the remote repo:\n$github_repo"; repo_status="new";fi


}

#TODO: test on windows
setup_git_config () {
    local repo="$1"
    local template="$(builtin_topic_dir "git")/gitconfig.template"

    confirm_task "configure" "git for $repo"

    if [ $? -eq 1 ]; then return; fi

    # make sure git is installed
    if ! cmd_exists git;then
        dotsys install git --recursive
    fi

    git_credential='cache'
    if [ "$PLATFORM" == "mac" ]; then
        git_credential='osxkeychain'
    fi

    # repo_cfg_file names (local and global gitconfig.symlink files)
    local repo_cfg_global="$(repo_dir "$repo")/git/gitconfig.symlink"
    local repo_cfg_local="$(repo_dir "$repo")/git/gitconfig.local.symlink"
    local cfg

    for cfg in "global" "local"; do
        local global_authorname="$(git config --global user.name || "none")"
        local global_authoremail="$(git config --global user.email || "none")"
        local authorname="$(git config --$cfg user.name)"
        local authoremail="$(git config --$cfg user.email)"
        local repo_cfg_file="repo_cfg_${cfg}"
        repo_cfg_file="${!repo_cfg_file}"

        local default_user="${authorname:-$global_authorname}"
        local default_email="${authoremail:-$global_authoremail}"


        if [ "$cfg" = "local" ]; then
            get_user_input "Use the global settings for your repo?"
            if [ $? -eq 0 ]; then
                cfg="none"
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

        # add global only configs
        if [ "$cfg" = "global" ]; then
            git config "--$cfg" credential.helper "$git_credential"
            success "$(printf "git %b$cfg credential%b set to: %b$git_credential%b" $green $rc $green $rc)"

        # create local config file in repo .git dir (git init will recognize and preserve it)
        elif [ "$cfg" = "local" ]; then
            local repo_git_dir="$(repo_dir "$repo")/.git"
            mkdir -p "$repo_git_dir"
            touch "${repo_git_dir}/config"
        fi

        # add local/global configs
        if [ "$cfg" != "none" ]; then
            git config "--$cfg" user.name "$authorname"
            success "$(printf "git %b$cfg author%b set to:  %b$authorname%b" $green $rc $green $rc)"

            git config "--$cfg" user.email "$authoremail"
            success "$(printf "git %b$cfg email%b set to: %b$authoremail%b" $green $rc $green $rc)"

            git config "--$cfg" include.path "$repo_cfg_file"
            success "$(printf "git %b$cfg include%b set to: %b$repo_cfg_file%b" $green $rc $green $rc)"
        fi

        # make custom stub file and add to internal user directory
        if [ "$cfg" != "none" ]; then
            local stub_dir="$(stub_topic_dir "git")"
            local stub_name=".gitconfig"
            if [ "$cfg" = "local" ]; then
                stub_name+=".local"
            fi

            local stub_file="${stub_dir}/${stub_name}.stub"

            mkdir -p "$stub_dir"

            # create the custom stub file
            sed -e "s/AUTHORNAME/$authorname/g" \
                -e "s/AUTHOREMAIL/$authoremail/g" \
                -e "s/CREDENTIAL_HELPER/$git_credential/g" \
                -e "s|INCLUDE|$repo_cfg_file'|g" "$template" > "$stub_file"

            success_or_fail $? "created" "$(printf "stub file for %b$cfg git configuration%b:
                $spacer ->%b$stub_file%b" $green $rc $green $rc)"

        fi
    done

    success "Git has been configured for $repo"

}



is_git (){
    local repo="${1:-$repo}"
    local repo_dir="$(repo_dir "$repo")"
    local OWD="$PWD"
    cd "$repo_dir"
    [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1
    cd "$OWD"
}


copy_topics_to_repo () {

    local repo="$1"
    local dir="$(dotfiles_dir)"
    local repo_dir="$(repo_dir "$repo")"
    local confirmed
    local mode


    local question="$(printf "Would you like to %badd%b existing topics from %b%s%b
                    $spacer %b(You will be asked to confirm each topic before import)%b" \
                    $green $rc \
                    $green "$dir" $rc \
                    $dark_gray $rc )"
    local options="$(printf "\n$spacer %b(y)es%b, %b(n)o%b, or %bpath/to/directory%b" \
                    $yellow $rc \
                    $yellow $rc \
                    $yellow $rc)"

    while true; do
        local user_input=
        get_user_input "${question}?" -t "yes" -f "no" -o "$options" -i "false" -c
        case "$user_input" in
            yes ) break ;;
            no  ) return ;;
            *   ) if [ -d "$user_input" ] ; then dir="$user_input"; break; fi
        esac
    done

    local found_dirs=($(get_dir_list "$dir"))

    # list found topics
    if [ "$found_dirs" ]; then
        task "$(printf "Import topics found in %b$dir%b:" $green $rc)"
        local i
        for i in "${!found_dirs[@]}"; do
            local topic="${found_dirs[$i]}"
            local files="$(find "$dir/$topic" -maxdepth 1 -type f)"
            local is_repo="$(find "$dir/$topic" -maxdepth 2 -type f -name dotsys*)"

            # a topic must not be a repo or match current $repo user
            # and must contain at lest one recognised file type in topic root
            if [ "$files" ] && ! [ "$is_repo" ] && ! [ "$topic" = "${repo%/*}" ]; then
                local f
                for f in $files; do
                    if ! [[ "$f" =~ (*.symlink|*.sh|*.zsh) ]]; then
                        unset found_dirs[$i]
                        continue
                    fi
                done
            fi
            msg "$spacer - $topic"
        done

    # noting to import
    else
       task "$(printf "Import topics not found in %b$dir%b:" $green $rc)"
       return
    fi

    question="$(printf "Would you like to %b(c)bopy%b, %b(m)ove%b, or %b(a)bort%b all topics" $yellow $rc $yellow $rc $yellow $rc)"

    get_user_input "${question}?" -t move -f copy -o "" -c
    if [ $? -eq 0 ]; then mode=move; else mode=copy; fi


    local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"
    # Confirm each file to move/copy
    local topic
    for topic in ${found_dirs[@]}; do
        confirm_task "$mode" "$topic \n$spacer from $dir \n$spacer to $repo_dir"
        if [ $? -eq 0 ]; then
            clear_lines "" 2 #clear task confirm
            #local topic="${t##*/}"
            printf "$dark_gray"
            if [ "$mode" = "copy" ]; then
                cp -LRai "${dir}/$topic" "${repo_dir}/$topic"
            elif [ "$mode" = "move" ]; then
                mv -i "${dir}/$topic" "${repo_dir}/$topic"
            fi
            printf "$rc"

            success_or_fail $? "$mode" "$(printf "$(cap_first $mode) %b$topic%b: %b$repo_dir%b" $green $rc $green $rc)"

        else
          clear_lines "" 2 # clear two lines of
        fi
    done

}

confirm_make_primary_repo (){
    local repo="$1"
    # if repo is same as state, bypass check
    if [ "$(state_primary_repo)" = "$repo" ]; then return ; fi

    confirm_task "make" "this your primary repo "$(repo_dir "$repo")""
    if [ $? -eq 0 ]; then
        state_primary_repo "$repo"
        set_user_vars "$repo"
        success "$(printf "New primary repo: %b$repo%b" $green $rc)"
    fi
}

# determines the active repo config -> state
get_active_repo () {
  # check for config repo
  local repo="$(get_config_val "_repo")"
  # primary repo
  if ! [ "$repo" ]; then
      repo="$(state_primary_repo)"
      set_user_vars "$repo"
  fi
  echo "$repo"
}

# Determine if the repo is present in any state file
repo_in_use () {
    local repo="$1"
    local states="$(get_state_list)"
    local s
    for s in $states; do
        if in_state "$s" "!repo" "$repo"; then
        return 0; fi
    done
    return 1
}
