#!/usr/bin/env bash

set_default_managers (){

  DEFAULT_APP_MANAGER="$(get_topic_config_val "" "app_manager")"
  DEFAULT_CMD_MANAGER="$(get_topic_config_val "" "cmd_manager" )"

  info "$(printf "App package manager: %b%s%b" $green $DEFAULT_APP_MANAGER $rc)"
  info "$(printf "Cmd Package manager: %b%s%b" $green $DEFAULT_CMD_MANAGER $rc)"
}

run_manager_task () {
  local manager="$1"; shift
  local action="$1"; shift
  local topics=()
  local force

  while [[ $# > 0 ]]; do
    case $1 in
      --force)          force="--force";;
      * )               topics+=("$1") ;;
    esac
    shift
  done

  required_vars "manager" "action" "topics"

  debug "-- run_manager_task: m:$manager a:$action t:$topics f:$force"

  # abort unmanned topics
  if ! [ "$manager" ]; then
    debug "aborting run_manager_task $topic not managed"
    return
  fi

  # abort update actions (nothing to do)
  if [ "$action" = "update" ]; then
    debug "aborting run_manager_task UPDATE not used"
    return
  fi

  # convert topic to appropriate package name
  local packages=()
  for topic in ${topics[@]}; do

     # check if already installed on install action
     if [ "$action" = "install" ] && [ ! "$force" ] && is_installed "$manager" "$topic"; then
       success "$(printf "%b$(cap_first "$manager")%b already ${action}ed %b%s%b" $green $rc $green $topic $rc )"
     continue; fi

     # convert topic to package name
     load_topic_config_vars "$topic"
     local pkg_name="$(get_topic_config_val $topic $manager)"
     if ! [ "$pkg_name" ]; then pkg_name="$topic"; fi

     debug "CONVERTED $topic to $pkg_name for $manager"

     # run the manager task
     run_script_func "$manager" "manager.sh" "$action" "$pkg_name" "$force" -required

     # record success to state file
     if [ $? -eq 0 ]; then
         if [ "$action" = "install" ]; then
           state_install "$manager" "$topic"
         elif [ "$action" = "uninstall" ]; then
           state_uninstall "$manager" "$topic"
         fi
     fi
  done

  #run_script_func "$manager" "manager.sh" "$action" ${packages[@]} -required

}

install_dependencies () {
  # TODO: test dependancy install
  local topic="$1"
  local deps="$(get_topic_config_val $topic "deps")"

  if ! [ "$deps" ]; then return 0; fi

  info "$(printf "Installing %b%s%b's dependencies %s" $green $topic $rc "$DRY_RUN")"

  for dep in ${deps[@]}; do
    # Check if dep is installed
    if ! cmd_exists "$dep";then
      dotsys "install" "$dep" from "$ACTIVE_REPO"
    else
      success "$(printf "Already installed dependency %s%b%s%b" "$DRY_RUN" $light_green "$dep" $rc)"
    fi
  done

}

get_package_list () {
  local manger="$1"
  shift

  local package_file="$(topic_dir $manager)/packages.yaml"
  local array=()

  if [ -f "$package_file" ];then
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

    local packages=$(get_package_list "$manager")
    if [ "$packages" ]; then
        task "$(printf "${action}ing %s%b$manager's%b packages" "$DRY_RUN" $light_green $rc)"
        run_manager_task "$manager" "$action" "$force" $packages
    fi
}


