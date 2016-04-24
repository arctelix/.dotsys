#!/usr/bin/env bash

manage_repo (){
    local action=
    local repo=
    local branch="master" #todo: implement branch section

    local github_repo="https://github.com/$repo"
    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"

    local user_name="$(cap_first ${repo%/*})"
    local repo_name="${repo#*/}"
    local state_key="installed_repo"
    local TOPIC_CONFIRMED="$GLOBAL_CONFIRMED"


    local force
    local silent

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )    force="$1" ;;
        -s | --silent)  silent="$1" ;;
        -*)  invalid_option ;;
        *)  uncaught_case "$1" "action" "repo" "branch" ;;
        esac
        shift
    done

    debug "-- manage_repo: a:$action repo:$repo force:$force silent:$silent"

    # determine repo status
    is_installed "dotsys" "$state_key" "$repo"
    local repo_status=$?

    if [ "$action" = "install" ] && [ $repo_status -eq 0 ] && ! [ "$force" ]; then
        repo_status="abort"
    elif [ "$action" = "uninstall" ] && ! [ $repo_status -eq 0 ] && ! [ "$force" ]; then
        repo_status="abort"
    elif ! [ -d "$local_repo" ]; then
        # check for remote
        wget "${github_repo}.git" --no-check-certificate -o /dev/null
        # remote repo found
        if [ "$?" -eq 0 ]; then
            repo_status="remote"
        # no remote repo or directory
        else
            repo_status="new"
        fi
    else
        repo_status="existing"
    fi

    # make sure repo is properly installed (unless installing)
    if [ "$repo_status" != "abort" ] && [ "$action" != "install" ]; then
        # Check existing for git
        if [ "$repo_status" = "existing" ] && ! [ -d "${local_repo}/.git" ];then
            msg "$(printf "Warning: An existing local directory named $repo was found, but \
            it's not installed for use with dotsys.")"
            action="install"

        # Check for non existing repo
        elif [ "$repo_status" != "existing" ]; then
            error "$(printf "The specified repo %b$repo%b does not exist.
            \rPlease make sure it is spelled correctly and in your '.dotfiles' directory." $blue $red)"

            msg "$(printf "HINT: You can run'dotsys install $repo' to create or download new repos.%s" "\n")"

            action="install"
        fi
    fi

    # confirm action or abort
    if [ "$repo_status" = "abort" ]; then
        task "$(printf "Already ${action%e}ed: %b$repo%b" $green $blue)"
        return
    elif ! [ "$silent" ] && ! [ "$TOPIC_CONFIRMED" ]; then
        confirm_task "$action" "$repo_status repo: $local_repo"
        if ! [ $? -eq 0 ]; then return;fi
    fi

    # check for primary repo or exit
#    if ! [ "$(state_primary_repo)" ]; then
#        error "$(printf "In order for dotsys to work you will need to create a repository.
#              \rRun 'dotsys install' to create or download an existing repo.")"
#        exit
#    fi

    # START ACTIONS
    local action_status=1

    if [ "$action" = "install" ]; then

        # change into local repo directory
        if [ "$repo_status" != "existing" ];then
            mkdir -p "$local_repo"
        fi

        cd "$local_repo"

        if ! [ $? -eq 0 ]; then error "Local repo could not be created"; exit; fi

        # make sure repo is git!
        if ! is_git; then
            confirm_task "initialize" "\n$spacer $repo_status repo $local_repo"
            if ! [ $? -eq 0 ]; then exit; fi

            # force existing to push to git
            if [ "$repo_status" == "existing" ];then repo_status=new; fi

            if ! [ -f ".dotsys.cfg" ]; then
                touch .dotsys.cfg
                echo "repo:${repo}" >> ".dotsys.cfg"
            fi

            git init
            git remote add origin "$github_repo"
            git remote -v
            git add .
            git commit -m "initialized by dotsys"

            if [ "$?" -eq 0 ]; then
                success "$(printf "Initialize %b$repo_status%b local repo %b$local_repo%b" $green $rc $green $rc)"
            else
                error "$(printf "Initialize %b$repo_status%b local repo %b$local_repo%b" $green $rc $green $rc)"
                exit
            fi
        fi

        # REMOTE: Has existing remote repo
        if [ "$repo_status" = "remote" ];then
            git fetch origin master
            if [ "$?" -eq 0 ]; then
                success "$(printf "Fetched existing %b$repo_status%b repo %b$local_repo%b" $green $rc $green $rc)"
            else
                error "$(printf "Fetch existing %b$repo_status%b repo %b$local_repo%b" $green $rc $green $rc)"
                exit
            fi

        # NEW: initialize remote repo
        elif [ "$repo_status" = "new" ];then
            confirm_task "initialize" "remote repo" "$github_repo"
            if [ "$?" -eq 0 ]; then
                # Git hub will prompt for the user password
                curl -u "$user_name" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"
                git push origin master
                if ! [ $? -eq 0 ]; then
                    fail "$(printf "Initialize %b$repo_status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"
                    msg "$spacer However, The local repo is ready for topics..."
                else
                    success "$(printf "Initialize %b$repo_status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"

                fi
            fi
            msg "$spacer Don't forget to add topics to your new repo..."
        fi

        # exit repo directory
        cd "$OWD"

        state_install "dotsys" "$state_key" "$repo"
        action_status=$?

        confirm_make_primary_repo "$repo"

        # create dotsys-export.yaml
        confirm_task "freeze" "default repo configuration" "to ${repo}/.dotsys-default.cfg"
        if [ "$?" -eq 0 ]; then
            create_config_yaml "$repo"
        fi
        msg "$spacer HINT: Freeze your repo any time with 'dotsys freeze user/repo_name'"

    elif [ "$repo_status" = "update" ];then
        # this should pull if required but not push!
        echo "repo $action not implemented"
        action_status=$?

    elif [ "$action" = "upgrade" ]; then
        # this should push or pull as required
        update_repo "$repo"
        action_status=$?

    elif [ "$action" = "freeze" ]; then
        # list installed repos
        echo "repo $action not implemented"
        action_status=$?

    elif [ "$action" = "uninstall" ]; then
        if ! repo_in_use "$repo"; then
            if ! [ "$?" -eq 0 ]; then return; fi
            # remove from state only for now
            state_uninstall "dotsys" "$state_key" "$repo"
            action_status=$?
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

# look into this command
# git remote -v update

#TODO: test windows
setup_gitconfig () {
  if ! [ -f git/gitconfig.local.symlink ]
  then
    info 'setup gitconfig'

    git_credential='cache'
    if [ "$(get_platform)" == "mac" ]
    then
      git_credential='osxkeychain'
    fi

    user ' - What is your github author name?'
    read -e git_authorname
    user ' - What is your github author email?'
    read -e git_authoremail

    sed -e "s/AUTHORNAME/$git_authorname/g" -e "s/AUTHOREMAIL/$git_authoremail/g" -e "s/GIT_CREDENTIAL_HELPER/$git_credential/g" git/gitconfig.local.symlink.example > git/gitconfig.local.symlink

    success 'gitconfig'
  fi
}

# http://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
# must run 'git fetch' or 'git remote update' first
update_repo (){
    local repo="$1"
    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"

    cd "$local_repo"

    local LOCAL=$(git rev-parse @)
    local REMOTE=$(git rev-parse @{u})
    local BASE=$(git merge-base @ @{u})

    if [ $LOCAL = $REMOTE ]; then
        echo "Up-to-date"
    elif [ $LOCAL = $BASE ]; then
        echo "Need to pull"
    elif [ $REMOTE = $BASE ]; then
        echo "Need to push"
    else
        echo "Diverged"
    fi

    cd "$OWD"
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


    local question="$(printf "Would you like to search for existing topics to %bimport%b from %b%s%b \
                    \n$spacer (You will be asked to confirm each topic before import)" \
                    $green $rc \
                    $green "$dir" $rc )"
    local options="$(printf "\n$spacer Enter %b(y)es%b, %b(n)o%b, or %bpath/to/directory%b" \
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

    local repos=($(get_topic_list "$dir"))

    # list found topics
    if [ "$repos" ]; then

        task "$(printf "Import topics found in %b$dir%b:" $green $rc)"
        for i in "${!repos[@]}"; do
            local topic="${repos[$i]}"
            local files="$(find "$dir/$topic" -maxdepth 1 -type f)"
            # remove if topic matches user repo or if directory has no files
            if ! [ "$files" ] || [ "$topic" = "${repo%/*}" ]; then unset found[$i]; continue; fi
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

# determines the active repo
get_active_repo () {
  # check for config repo
  local repo="$(get_config_val "_repo")"

  # primary repo
  if ! [ "$repo" ]; then
      repo="$(state_primary_repo)"
      set_user_vars "$repo"

  # use default or new config
  elif ! [ "$repo" ]; then
      msg "There is no repo configured on your system.
      Although dotsys has a bare bones repo built in, you
      should configure a custom repo now."
      get_user_input "Would you like to configure your repo now"
      if ! [ "$?" -eq 0 ]; then
          repo="$(get_config_val "__repo")"
          set_user_vars "$repo"
      else
          new_user_config
      fi
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
