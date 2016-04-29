#!/usr/bin/env bash

manage_repo (){

    local usage="manage_repo <action> <repo> [<branch> <options>]"
    local usage_full="Installs and uninstalls dotsys.
    --force            Force the repo management
    --silent | -s      Manage repo without confirmations or messages
    "
    local action
    local repo
    local branch
    local force
    local silent

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )       force="$1" ;;
        *)  uncaught_case "$1" "action" "repo" "branch" ;;
        esac
        shift
    done

    required_vars "action" "repo"


    local github_repo="https://github.com/$repo"
    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"

    local repo_user="$(cap_first ${repo%/*})"
    local repo_name="${repo#*/}"
    local repo_user_dir="$(repo_dir "$repo_user")"
    local state_key="installed_repo"
    local confirmed="${TOPIC_CONFIRMED:-"$GLOBAL_CONFIRMED"}"



    # todo: implement branch for git
    branch="${branch:-master}"

    debug "-- manage repo a:$action r:$repo rd:$local_repo b:$branch $force $silent"

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
        info "Fund existing directory: $local_repo"
        repo_status="existing"
    else
        # check for remote
        info "Checking for remote $github_repo"
        wget "${github_repo}.git" --no-check-certificate -o /dev/null
        # remote repo found
        if [ "$?" -eq 0 ]; then
            info "Found remote repo: $github_repo"
            repo_status="remote"
        # no remote repo or directory
        else
            info "New repo supplied: $local_repo"
            repo_status="new"
        fi
    fi

    debug "   manage repo status: $repo_status"

    # Check for action already complete (we do this first in case of status changes in checks)
    if ! [ "$force" ]; then
        if [ "$action" = "install" ] && [ "$repo_status" = "installed" ]; then
            repo_status="action_done"

        elif [ "$action" = "uninstall" ] && [ ! "$repo_status" = "installed" ]; then
            repo_status="action_done"
        fi
    fi

    # PRECONFIRM CHECKS AND MESSAGES

    # NOTE: ALL REPO ACTIONS ARE HANDLED BEFORE ANYTHING ELSE (EXCEPT UNINSTALL IS LAST!)
    # TODO THIS SECTION NEEDS WORK!!!!!
    # install expects nothing
    if [ "$action" != "install" ]; then

        # ALL ACTIONS except install

        # missing directory (installed)
        if [ "$repo_status" = "missing" ] && repo_in_use "$repo" && ! [ "$force" ]; then
            warn "$(printf "The local repo $repo is $repo_status
                    $spacer and can not be ${action%e}ed.  If a remote repo exists
                    $spacer run 'dotsys install $repo' before ${action%e}ing.
                    $spacer Otherwise replace the repo with it's entire contents.
                    $spacer As a last resort run 'dotsys uninstall $repo --force'.")"
            confirmed=""
            action="install"
            repo_status="remote"

        # directory not found and (not installed)
        elif [ ! "$installed" ] && ! [ -d "$local_repo" ]; then
           error "$(printf "The repo $repo
                    $spacer was not found and can not be ${action%e}ed.
                    $spacer Check the spelling and make sure it is located
                    $spacer in $(dotfiles_dir).")"
           exit
        # directory exists but not installed
        elif [ ! "$installed" ]; then
            warn "$(printf "The $repo_status repo $repo must be
                    $spacer installed before it can be ${action%e}ed.")"
            confirmed=""
            action="install"
            repo_status="existing"

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

    # TODO END        THIS SECTION NEEDS WORK!!!!!


    # ABORT: ACTION DONE (we do this after the checks to make sure status has not changed)
    if [ "$repo_status" = "action_done" ]; then
        task "$(printf "Already ${action%e}ed: %b$repo%b" $green $blue)"
        return
    # CONFIRM
    elif ! [ "$confirmed" ]; then
        confirm_task "$action" "$repo_status repo: \n$spacer $local_repo"
        if ! [ $? -eq 0 ]; then return; fi
    fi




    # START ACTIONS

    local action_status=1

    if [ "$action" = "install" ]; then





        if ! [ $? -eq 0 ]; then error "Local repo $local_repo could not be created"; exit; fi

        # INSTALL GIT
        if ! cmd_exists git;then
            dotsys install git --recursive
        fi

        # REMOTE: Clone existing repo
        if [ "$repo_status" = "remote" ];then
            # make user directory (clone makes repo directory)
            mkdir -p "$repo_user_dir"
            cd "$repo_user_dir"
            git clone "$github_repo"
            if ! [ $? -eq 0 ]; then fail "Could not fetch the remote repo:\n$github_repo"; repo_status="new";fi

        # create full repo directory
        elif [ "$repo_status" != "existing" ];then
            mkdir -p "$local_repo"
        fi

        cd "$local_repo"

        # SET GIT CONFIG
            setup_git_config "$repo"

        # make sure repo is git!
        if ! is_git; then

            confirm_task "initialize" "$repo_status repo for git:\n$spacer  $local_repo"
            if ! [ $? -eq 0 ]; then exit; fi

            # existing -> new since it's not git
            if [ "$repo_status" = "existing" ];then
                repo_status="new";
            fi

            # add a .dotsys.cfg
            if ! [ -f ".dotsys.cfg" ]; then
                touch .dotsys.cfg
                echo "repo:${repo}" >> ".dotsys.cfg"
            fi

            git init
            git remote add origin "$github_repo"
            git remote -v

            if [ "$?" -eq 0 ]; then
                success "$(printf "Initialize %b$repo_status%b local repo %b$local_repo%b" $green $rc $green $rc)"
            else
                error "$(printf "Initialize %b$repo_status%b local repo %b$local_repo%b" $green $rc $green $rc)"
                exit
            fi
        fi


        # NEW: initialize remote repo
        if [ "$repo_status" = "new" ];then
            git add .
            git commit -m "initialized by dotsys"

            confirm_task "initialize" "remote repo" "$github_repo"
            if [ "$?" -eq 0 ]; then
                # Git hub will prompt for the user password
                local resp=`curl -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"`
                git push origin master
                if ! [ $? -eq 0 ]; then
                    fail "$(printf "Initialize %b$repo_status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"
                    msg "$spacer However, The local repo is ready for topics..."
                else
                    success "$(printf "Initialize %b$repo_status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"

                fi
            fi

            msg "$spacer Don't forget to add topics to your new repo..."

            copy_topics_to_repo "$repo"
        fi

        # exit repo directory
        cd "$OWD"

        state_install "dotsys" "$state_key" "$repo"
        action_status=$?

        # if repo is not already the primary offer some options
        if ! [ "$(state_primary_repo)" = "$repo" ]; then

            confirm_make_primary_repo "$repo"

            # create dotsys-export.yaml
            confirm_task "freeze" "repo" "to ${repo}/.dotsys-default.cfg"
            if [ "$?" -eq 0 ]; then
                create_config_yaml "$repo"
            fi
            msg "$spacer HINT: Freeze any time with 'dotsys freeze user/repo_name'"
        fi

    elif [ "$repo_status" = "update" ];then
        # this should pull if required but not push!
        manage_remote_repo "$repo" pull
        echo "repo $action not implemented"
        action_status=$?

    elif [ "$action" = "upgrade" ]; then
        # this should push or pull as required
        manage_remote_repo "$repo"
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
            get_user_input "Would you like to delete local repo $repo and push
                    $spacer to $github_repo?"
            # delete local repo
            if [ $? -eq 0 ]; then
                manage_remote_repo "$repo" push
                #debug "   manage repo: Would have removed $local_repo"
                rm -rf "$local_repo"
            fi
        fi
    fi

    # Success / fail message
    if ! [ "$silent" ]; then
        if [ $action_status -eq 0 ]; then
            success "$(printf "$(cap_first "$action")ed $repo_status repo %b$local_repo%b" $green $rc)"
        else
            fail "$(printf "$(cap_first "$action") $repo_status repo %b$local_repo%b" $green $rc)"
        fi
    fi

    return 0
}


#TODO: test on windows
setup_git_config () {
    local repo="$1"
    local template="$(builtin_topic_dir "git")/gitconfig.template"

    confirm_task "setup the gitconfig for $repo"
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
            get_user_input "Use the global settings for your repo"
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

            if [ $? -eq 0 ]; then
                success "$(printf "Stub file created for %b$cfg git configuration%b:
                $spacer ->%b$stub_file%b" $green $rc $green $rc)"
            else
                fail "$(printf "Stub file NOT created for %b$cfg git configuration%b:
                $spacer ->%b$stub_file%b" $green $rc $green $rc)"
            fi

        fi
    done

    success "Git has been configured for $repo"

}


manage_remote_repo (){

    local usage="dotsys [<action>]"
    local usage_full="
    auto            Automatically push or pull appropriately
    push            Push local changes to remote behind
    pull )          Pull remote changes to local if behind
    "
    local repo="$1"; shift
    local action="${2:-auto}"

    case "$1" in
      auto )        action="$1" ;;
      push )        action="$1" ;;
      pull )        action="$1" ;;
      status )      action="$1" ;;
      * ) invalid_option;;
    esac
    shift

    debug "-- manage_remote_repo: $action"

    local local_repo="$(repo_dir "$repo")"
    local remote_repo="https://github.com/$repo"
    local result
    local OWD="$PWD"

    task "Git $action $$repo"


    if [ "$action" = "auto" ] || [ "$action" = "status" ]; then
        # http://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
        # must run 'git fetch' or 'git remote update' first

        cd "$local_repo"

        git remote update

        local LOCAL=$(git rev-parse @)
        local REMOTE=$(git rev-parse @{u})
        local BASE=$(git merge-base @ @{u})

        cd "$OWD"

        if [ $LOCAL = $REMOTE ]; then
            action="up-to-date"
        elif [ $LOCAL = $BASE ]; then
            action="pull"
        elif [ $REMOTE = $BASE ]; then
            action="push"
        else
            action="diverged"
        fi
    fi

    if [ "$action" = "status" ]; then
        echo "$action"
        return
    fi

    # execute push/pull
    if [ "$action" = "push" ];then
        cd "$local_repo"
        result=`git push origin master`
        cd "$OWD"

    elif [ "$action" = "pull" ];then
        cd "$local_repo"
        result=`git pull origin master`
        cd "$OWD"

    elif [ "$action" = "diverged" ];then
       fail "$(printf "Remote repo ${action}")"
       return

    elif [ "$action" = "up-to-date" ];then
       success "$(printf "Remote repo ${action}")"
       return
    fi

    if ! [ $? -eq 0 ]; then
        fail "$(printf "Remote repo failed to ${action}:
                $spacer -> $result")"
    else

        success "$(printf "Remote repo ${action%e}ed:
                   $spacer -> $result")"
    fi
}


is_git (){
    [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1
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
        get_user_input "$question" -t "yes" -f "no" -o "$options" -i "false" -c
        case "$user_input" in
            yes ) break ;;
            no  ) return ;;
            *   ) if [ -d "$user_input" ] ; then dir="$user_input"; break; fi
        esac
    done

    local repos=($(get_dir_list "$dir"))

    # list found topics
    if [ "$repos" ]; then

        task "$(printf "Import topics found in %b$dir%b:" $green $rc)"
        for i in "${!repos[@]}"; do
            local topic="${repos[$i]}"
            local files="$(find "$dir/$topic" -maxdepth 1 -type f)"
            # remove if topic matches user repo or if directory has no files
            if ! [ "$files" ] || [ "$topic" = "${repo%/*}" ]; then unset repos[$i]; continue; fi
            msg "$spacer - $topic"
        done

    # noting to import
    else
       task "$(printf "Import topics not found in %b$dir%b:" $green $rc)"
       return
    fi

    question="$(printf "Would you like to %b(c)bopy%b, %b(m)ove%b, or %b(a)bort%b all topics" $yellow $rc $yellow $rc $yellow $rc)"

    get_user_input "$question" -t move -f copy -o "" -c
    if [ $? -eq 0 ]; then mode=move; else mode=copy; fi


    local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"
    # Confirm each file to move/copy
    for topic in ${repos[@]}; do
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
            if [ $? -eq 0 ]; then
                success "$(printf "$(cap_first $mode) %b$topic%b: %b$repo_dir%b" $green $rc $green $rc)"
            else
                fail "$(printf "$(cap_first $mode) %b$topic%b to %b$repo_dir%b" $green $rc $green $rc)"
            fi
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
