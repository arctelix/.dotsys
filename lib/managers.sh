#!/usr/bin/env bash

set_default_managers (){
  DEFAULT_APP_MANAGER="$(get_topic_config_val "" "app_manager")"
  DEFAULT_CMD_MANAGER="$(get_topic_config_val "" "cmd_manager" )"
}

get_default_manager (){
    local manager="$1"
    # convert generic names to defaults
    if [ "$manager" = "cmd" ]; then
      manager="$DEFAULT_CMD_MANAGER"
    elif [ "$manager" = "app" ]; then
      manager="$DEFAULT_APP_MANAGER"
    fi
    echo "$manager"
}

get_topic_manager () {
    local topic="$1"
    local manager=$(get_topic_config_val "$topic" "manager")
    # check unmanned topic
    if ! [ "$manager" ]; then return 1; fi
    debug "  - get_topic_manager: $manager"
    # check cmd/app
    manager="$(get_default_manager "$manager")"
    echo "$manager"
    return 0
}

is_managed () {
 local topic="${1:-$topic}"
 get_topic_manager "$topic" > /dev/null
 return $?
}

run_manager_task () {
  local usage="run_manager_task <manager> <action> <topics>"
  local usage_full="Installs and uninstalls dotsys.
  --force        force install if installed
  --packages     the topics supplied are packages from package file
  "
  local manager="$1"; shift
  local action="$1"; shift
  local topics=()
  local packages
  local force

  while [[ $# > 0 ]]; do
    case $1 in
      --force)          force="--force";;
      --packages)       packages="--force";;
      * )               topics+=("$1") ;;
    esac
    shift
  done

  required_vars "manager" "action" "topics"

  debug "-- run_manager_task: m:$manager a:$action t:$topics f:$force"

  # convert topic to manager (allows main to throw all topics this way)
  if ! is_manager "$manager"; then
    debug "   run_manager_task: got NON manager: $manager"
    manager="$(get_topic_manager "$manager")"
    debug "   run_manager_task: got NON manager found manager: $manager"
  fi

  # abort un-managed topics

  if ! [ "$manager" ] || [ "$manager" = "${topics[0]}" ]; then
    debug "   run_manager_task: ABORT $topic not managed"
    return
  fi

  # make sure the topic manager is installed on system
  if [ "$action" = "install" ] && ! is_installed "system" "$manager"; then
     info "${action}ing manager" "$(printf "%b$manager" "$hc_topic")" "for" "$(printf "%b${topics[*]}" "$hc_topic")"
     # install the manager
     dotsys "$action" "$manager" ${limits[@]} --recursive
     debug "run_manager_task -> END RECURSION continue : run_manager_task $manager $action t:$topic $force"
     info "Manager ${action%e}ed, resuming" "$( printf "%b$action ${topics[*]}" "$hc_topic")"
  fi

  # abort update & freeze actions (nothing to do)
  if [ "$action" = "update" ] || [ "$action" = "freeze" ]; then
    debug "   run_manager_task: aborting run_manager_task UPDATE FREEZE not used"
    return
  fi

  # Install topics (packages)
  local topic
  for topic in ${topics[@]}; do

     # check if already installed (not testing for repo!)
     if [ "$action" = "install" ] && [ ! "$force" ] && is_installed "$manager" "$topic" --manager ; then
        # Only show the message if is actually installed on manager state
        if is_installed "$manager" "$topic"; then
            success "The package for" "$( printf "%b$topic" "$hc_topic")," "was already ${action}ed by dotsys"
        fi
        continue
     # check if already uninstalled (not testing for repo!)
     elif [ "$action" = "uninstall" ] && [ ! "$force" ] && ! is_installed "$manager" "$topic" --manager; then
        # Only show the message if is actually uninstalled on manager state
        if ! is_installed "$manager" "$topic"; then
            success "The package for" "$( printf "%b$topic" "$hc_topic")," "was already ${action}ed by dotsys"
        fi
        continue
     fi

     # only confirm packages, actual topics will be confirmed by script_manager
     if [ "$packages" ]; then
        confirm_task "$action" "${manager}'s package" "$topic" --confvar "PACKAGES_CONFIRMED"
        if ! [ $? -eq 0 ]; then continue;fi
     fi

     # convert topic to package name
     load_topic_config_vars "$topic"
     local pkg_name="$(get_topic_config_val $topic $manager)"
     if ! [ "$pkg_name" ]; then pkg_name="$(get_topic_config_val $topic "package_name")"; fi
     if ! [ "$pkg_name" ]; then pkg_name="$topic"; fi

     debug "   run_manager_task for $manager: $topic CONVERTED to package name '$pkg_name' "

     # run the manager task
     run_script_func "$manager" "manager.sh" "$action" "$pkg_name" "$force" -required

     # record success to state file (10 = not found, but not required)
     if [ $? -le 10 ]; then
         debug "   run_manager_task: script exit = $?"
         if [ "$action" = "install" ]; then
           state_install "$manager" "$topic"
         elif [ "$action" = "uninstall" ]; then
           state_uninstall "$manager" "$topic"
         fi
     fi
  done

  #run_script_func "$manager" "manager.sh" "$action" ${packages[@]} -required

}

manage_dependencies () {
  local action="$1"
  local topic="$2"
  local deps="$(get_topic_config_val $topic "deps")"

  debug "-- manage_dependencies: $action $topic deps: $deps"

  # check if topic is in use by other topics
  if [ "$action" = "uninstall" ]; then
    if topic_in_use "$topic"; then
        warn "$topic is in use and can not be uninstalled yet"
        ACTIVE_TOPICS+=($topic)
        debug "   manage_dependencies: $topic in use add to ACTIVE_TOPICS"
        return 1
    else
        debug "   manage_dependencies: remove $topic from ACTIVE_TOPICs"
        #remove topic from active
        ACTIVE_TOPICS=(${ACTIVE_TOPICS[@]/$topic/})
    fi

  # Deps only need install / uninstall
  elif [ "$action" != "install" ]; then
    return 0
  fi

  # abort here if topic has no deps
  if ! [ "$deps" ]; then
    debug "   No DEPENDENCIES required for $topic"
    return 0
  fi

  debug "   manage_dependencies: $action $topic has deps: $deps"

  local done=()
  local dep
  local task_shown
  for dep in $deps; do
    # filter duplicates from user topic and builtin topics
    if [[ "${done[@]}" == *"$dep"* ]];then
        debug "   manage_dependencies: ABORT $dep duplicate from  builtin/user topic"
        continue
    fi
    done+=("$dep")

    if [ "$action" = "uninstall" ]; then
        state_uninstall "deps" "$dep" "$ACTIVE_REPO/$topic"
        debug "   manage_dependencies: removed $topic:$dep from state"

    # handle install
    else
        # only show the message for first dependency
        if ! [ "$task_shown" ]; then
          info "Installing" "$( printf "%b$topic" "$hc_topic")'s" "dependencies $DRY_RUN"
          task_shown="true"
        fi
        # install
        if ! is_installed "system" "$dep";then
          dotsys "install" "$dep" --recursive
          if [ $? -eq 0 ]; then
            debug "state_install: deps $dep $topic $ACTIVE_REPO"
          fi
        # already installed
        else
          success "Dependency Already installed $DRY_RUN:" "$( printf "%b$dep" "$hc_topic")"
        fi
        # Add dep to deps state
        state_install "deps" "$dep" "$ACTIVE_REPO/$topic"
    fi
  done

  if [ "$action" = "install" ]; then
    info "Dependencies ${action%e}ed, resuming" "$( printf "%b$action $topic" "$hc_topic")"
  fi

}


get_package_list () {
  local manager="$1"
  local option="$2"
  local package_file

  local usage="get_package_list <manager> <option>"
  local usage_full="Gets a manager's packages from 'file' or from installed 'packages' state"

  case "$2" in
    -i | packages ) option=packages ;;
    -f | file )     option=file ;;
    * ) invalid_option "$1";;
  esac

  # get packages from state
  if [ "$option" = "packages" ]; then
    package_file="$(state_file "$manager")"

  # get packages from manager's package file
  elif [ "$option" = "file" ]; then
    package_file="$(topic_dir "$manager")/packages.yaml"
  else
    return
  fi
  local array=()

  if [ -f "$package_file" ];then
    local key
    local val
    while IFS=":" read -r key val; do
        if [ "$key" ] && [[ "${key:0:1}" != "#" ]] && ! [[ "$val" =~ ^(x| x|no| no)$ ]]; then
          array+=("$key")
        fi
    done < "$package_file"
  else
    return
  fi
  echo "${array[@]}"
}

manage_packages () {
    local action="$1"
    local manager="$2"
    shift; shift
    local packages=()
    local option="file"
    local force

    local usage="manage_packages <action> <manager> [<packages> | <option>]"
    local usage_full="
    Perform action on all installed packages (install will always use package file):
       manage_packages <action> brew packages
       manage_packages <action> brew
    Perform action on provided packages (any manager recognized package name)
       manage_packages <action> brew <package> ..
    Perform action on packages in package file only
       manage_packages <action> brew file
    "

    # Managers do not freeze or update their packages
    # If the package has these features use a topic.sh function for the package
    if [ "$action" = "freeze" ] || [ "$action" = "update" ]; then return;fi



    while [[ $# > 0 ]]; do
        case "$1" in
        packages )      option="packages" ;;
        file )          option="file" ;;
        --force )       force="$1" ;;
        *)              packages+=("$1") ;;
        esac
        shift
    done

    debug "-- manage_packages: p:$packages o:$option f:$force"

    if ! [ "${packages[0]}" ]; then
        packages=$(get_package_list "$manager" "$option")
    else
        packages="${packages[@]}"
    fi

    if ! [ "$packages" ]; then return; fi

    debug "   manage_packages final packages: $packages"

    task "${action}ing $DRY_RUN" "$(printf "%b$manager's" "$hc_topic")" "packages"

    run_manager_task "$manager" "$action" $packages "$force" --packages
}

# Checks for manager file
is_manager () {
    local topic="${1:-$topic}"
    local r=1

    # accept app and cmd
    topic="$(get_default_manager "$topic")"
    if [ -f "$(topic_dir "$topic")/manager.sh" ]; then r=0;
    elif [ -f "$(builtin_topic_dir "$topic")/manager.sh" ]; then r=0; fi

    debug "   - is_manager: $topic = $r"
    return $r
}

manager_in_use () {
    local manager="${1:-$topic}"
    if ! is_manager "$manager"; then return 1;fi
    # if anything is in manager sate file it's in use
    in_state "$manager" ""
    local r=$?
    debug "   - manager_in_use: $manager = $r"
    return $r
}

topic_in_use () {
    local topic="${1:-$topic}"
    # If the topic is a key in deps.state then it can not be
    # uninstalled until all it's dependant topics are uninstalled.
    in_state "deps" "$topic" "$ACTIVE_REPO"
    local r=$?
    debug "   - topic_in_use: $topic = $r"
    return $r
}
