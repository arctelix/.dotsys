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
    if ! [ "$manager" ]; then return; fi
    # check cmd/app
    manager="$(get_default_manager "$manager")"
    echo "$manager"
}

run_manager_task () {
  local usage="run_manager_task <manager> <action> <topics>"
  local usage_full="Installs and uninstalls dotsys.

  --force        force install if installed
  "
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
    debug "   run_manager_task: aborting run_manager_task $topic not managed"
    return
  fi

  # abort update actions (nothing to do)
  if [ "$action" = "update" ]; then
    debug "   run_manager_task: aborting run_manager_task UPDATE not used"
    return
  fi

  # Install topics (packages)
  local topic
  for topic in ${topics[@]}; do

     # check if already installed on install action
     if [ "$action" = "install" ] && [ ! "$force" ] && is_installed "$manager" "$topic"; then
        success "$(printf "%b$(cap_first "$manager")%b already ${action}ed %b%s%b" $green $rc $green $topic $rc )"
        continue
     # check if already uninstalled on install action
     elif [ "$action" = "uninstall" ] && [ ! "$force" ] && ! is_installed "$manager" "$topic"; then
        success "$(printf "%b$(cap_first "$manager")%b already ${action}ed %b%s%b" $green $rc $green $topic $rc )"
        continue
     fi

     # convert topic to package name
     load_topic_config_vars "$topic"
     local pkg_name="$(get_topic_config_val $topic $manager)"
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

install_dependencies () {
  # TODO: test dependancy install
  local topic="$1"
  local deps="$(get_topic_config_val $topic "deps")"

  if ! [ "$deps" ]; then return 0; fi

  info "$(printf "Installing %b%s%b's dependencies %s" $green $topic $rc "$DRY_RUN")"
  local dep
  for dep in ${deps[@]}; do
    # Check if dep is installed
    if ! cmd_exists "$dep";then
      dotsys "install" "$dep" from "$ACTIVE_REPO" --recursive
    else
      success "$(printf "Already installed dependency %s%b%s%b" "$DRY_RUN" $green "$dep" $rc)"
    fi
  done

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
    * ) invalid_option ;;
  esac

  # get packages from state for all other actions
  if [ "$option" = "packages" ]; then
    package_file="$(state_file "$manager")"

  # get packages from manager package file
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

    # todo: add / remove itemized packages to package file

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

    if ! [ "${packages[@]}" ]; then
        # Noting to install without package name or file
        if ! [ "$action" = "install" ]; then option="file";fi

        packages=$(get_package_list "$manager" "$option")
        debug "   get_package_list: $packages"
    else
        packages="${packages[@]}"
    fi

    if ! [ "$packages" ]; then return; fi

    debug "   manage_packages final packages: $packages"

    task "$(printf "${action}ing %s%b$manager's%b packages" "$DRY_RUN" $green $rc)"
    run_manager_task "$manager" "$action" $packages "$force"

}

# Checks for manager file
is_manager () {
    local topic="${1:-$topic}"
    local r=1
    if [ -f "$(topic_dir "$topic")/manager.sh" ]; then r=0;
    elif [ -f "$(builtin_topic_dir "$topic")/manager.sh" ]; then r=0; fi

    debug "   - is_manager: $topic = $r"
    return $r
}

manager_in_use () {
    local manager="${1:-$topic}"
    if ! is_manager "$manager"; then return 1;fi

    in_state "$manager" ""
    local r=$?
    debug "   - manager_in_use: $manager = $r"
    return $r
}

