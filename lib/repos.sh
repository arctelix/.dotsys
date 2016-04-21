#!/usr/bin/env bash

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

manage_repo (){
    local action="$1"
    local repo="$2"
    #todo: split out branch
    local branch="${3:-master}"

    local github_repo="https://github.com/$repo"
    local local_repo="$(repo_dir "$repo")"
    local OWD="$PWD"

    local user_name="$(cap_first ${repo%/*})"
    local repo_name="${repo#*/}"

    local status=
    local P_STATE=


    if [ "$action" != "install" ] && ! [ -d "$local_repo" ]; then
        error "$(printf "The specified repo %b$repo%b does not exist.
        \rPlease make sure it is spelled correctly." $blue $red)"

        msg "$(printf "HINT: You can run'dotsys install $repo' to create or download new repos.%s" "\n")"

        action="install"
    fi

    # determine status
    if ! [ -d "$local_repo" ]; then
        # check for remote
        wget "${github_repo}.git" --no-check-certificate -o /dev/null
        # remote repo found
        if [ "$?" -eq 0 ]; then
            status="remote"
        # no remote repo or directory
        else
            status="new"
        fi
    else
         status="existing"
    fi


    if [ "$action" = "install" ]; then

        if [ "$status" = "existing" ];then
            msg "$(printf "Warning: An existing local directory named $repo was found.
            \rThe install command will convert it to a git repo, but will not modify it's contents.")"
        fi

        # begin install

        confirm_task "install" "$status repo: $local_repo"

        if ! [ $? -eq 0 ]; then
            if ! [ "$status" != "existing" ]; then
                error "$(printf "In order for dotsys to work you will need to create a repository.
                      \rRun 'dotsys install' to create or download one automatically.")"
            fi
            exit
        fi

        # change into local repo directory
        if [ "$status" != "existing" ];then
            mkdir -p "$local_repo"
        fi

        cd "$local_repo"
        if ! [ $? -eq 0 ]; then error "Local repo could not be created"; exit; fi

        # make sure repo is git!
        if ! is_git; then
            confirm_task "initialize" "\n$spacer $status repo $local_repo"
            if ! [ $? -eq 0 ]; then exit; fi

            # force existing to push to git
            if [ "$status" == "existing" ];then status=new; fi

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
                success "$(printf "Initialize %b$status%b local repo %b$local_repo%b" $green $rc $green $rc)"
            else
                error "$(printf "Initialize %b$status%b local repo %b$local_repo%b" $green $rc $green $rc)"
                exit
            fi
        fi

        # REMOTE: Has existing remote repo
        if [ "$status" = "remote" ];then
            git fetch origin master
            if [ "$?" -eq 0 ]; then
                success "$(printf "Fetched existing %b$status%b repo %b$local_repo%b" $green $rc $green $rc)"
            else
                error "$(printf "Fetch existing %b$status%b repo %b$local_repo%b" $green $rc $green $rc)"
                exit
            fi

        # NEW: initialize remote repo
        elif [ "$status" = "new" ];then
            confirm_task "initialize" "remote repo" "$github_repo"
            if [ "$?" -eq 0 ]; then
                # Git hub will prompt for the user password
                curl -u "$user_name" https://api.github.com/user/repos -d "{\"name\":\"${repo_name}\"}"
                git push origin master
                if ! [ $? -eq 0 ]; then
                    fail "$(printf "Initialize %b$status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"
                    msg "$spacer However, The local repo is ready for topics..."
                else
                    success "$(printf "Initialize %b$status%b  remote repo %b$github_repo%b" $green $rc $green $rc)"

                fi
            fi
            msg "$spacer Don't forget to add topics to your new repo..."
        fi

        # exit repo directory
        cd "$OWD"

        success "$(printf "$(cap_first "$action")ed $status repo %b$local_repo%b" $green $rc)"

        confirm_make_primary_repo "$repo"

        # create dotsys-export.yaml
        confirm_task "freeze" "repo configuration" "to ${repo}/.freeze.yaml"
        if [ "$?" -eq 0 ]; then
            create_config_yaml "$repo"
        fi
        msg "$spacer HINT: Freeze your repo any time with 'dotsys freeze user/repo_name'"

    elif [ "$status" = "update" ];then
        update_repo "$repo"

    elif [ "$action" = "uninstall" ]; then
        # remove local repo
        echo "repo $action not implemented"

    elif [ "$action" = "upgrade" ]; then
        # this should push or pull as required
        update_repo

    elif [ "$action" = "reload" ]; then
        # this should only pull if required
        echo "repo $action not implemented"

    elif [ "$action" = "freeze" ]; then
        # list installed repos
        echo "repo $action not implemented"
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

copy_topics_to_repo () {

    local repo="$1"
    local dir="$(dotfiles_dir)"
    local repo_dir="$(repo_dir "$repo")"
    local confirmed
    local mode


    local question="$(printf "Would you like to %bimport%b existing topics from %b%s%b \
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

    local found=($(get_topic_list "$dir"))
    if [ "$found" ]; then
        # list found topics
        task "$(printf "Import topics found in %b$dir%b:" $green $rc)"
        for i in "${!found[@]}"; do
            local topic="${found[$i]}"
            local files="$(find "$dir/$topic" -maxdepth 1 -type f)"
            # remove it topic matches user repo or if directory has no files
            if ! [ "$files" ] || [ "$topic" = "${repo%/*}" ]; then unset found[$i]; continue; fi
            msg "$spacer - $topic"
        done
    else
       # noting to import
       task "$(printf "Import topics not found in %b$dir%b:" $green $rc)"
       return
    fi

    question="$(printf "Would you like to %b(c)bopy%b, %b(m)ove%b, or %b(a)bort%b all topics" $yellow $rc $yellow $rc $yellow $rc)"

    get_user_input "$question" -t move -f copy -o "" -c
    if [ $? -eq 0 ]; then mode=move; else mode=copy; fi


    local P_STATE=
    # Confirm each file to move/copy
    for topic in ${found[@]}; do
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
    if [ "$(state_repo)" = "$repo" ]; then return ; fi

    confirm_task "make" "this your primary repo "$(repo_dir "$repo")""
    if [ $? -eq 0 ]; then
        state_repo "$repo"
        set_user_vars "$repo"
        success "$(printf "New primary repo: %b$repo%b" $green $rc)"
    fi
}

# determines the active repo
get_active_repo () {
  # check for config repo
  local repo="$(get_config_val "_repo")"

  # state repo
  if ! [ "$repo" ]; then
      repo="$(state_repo)"
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

