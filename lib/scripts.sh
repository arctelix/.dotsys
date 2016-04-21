#!/bin/sh

# All functions pertaining to running scripts
# Author: arctelix


# TODO: catch exit code 126 (permissions) for script execution

run_topic_script () {
  local action="$1"
  local topic="${2:-"$topic"}"
  shift; shift

  local required=
  while [[ $# > 0 ]]; do
    case "$1" in
      -r | -required ) required="$1" ;;
      * )  ;;
    esac
    shift
  done

  log "-- run_topic_script $action for $topic $required"

  local status=0
  # try topic.sh function call first
  if [ -f "$(topic_dir "$topic")/topic.sh" ];then
    run_script_func "$topic" "topic.sh" "$action" $packages $required
    status=$?

  # run individual action scripts
  else
    run_script "$(topic_dir "$topic")/${action}.sh" "$topic" "$action" $packages
    status=$?
  fi

  # no script required for topic
  if [ $status -eq 10 ]; then
     success "$(printf "No $action script supplied for %b$topic%b" $light_green $rc)"
  fi

  log "run_topic script received exit status [ $status ] for $topic $action"

  # install
  if [ "$action" = "install" ]; then
    if [ $status -le 10 ]; then # success
        # add to state file if not there
        state_install "dotsys" "$topic"
        INSTALLED+=($topic)
    fi

  # uninstall
  elif [ "$action" = "uninstall" ]; then
    if [ $status -le 10 ]; then # success
      # remove topic form state file
      state_uninstall "dotsys" "$topic"
      INSTALLED=( "${INSTALLED[@]/$topic}" )
    fi
  fi

  #return $status
}

# runs a specified script, and displays status, and logs
# 0     = everything ok
# 10   = script not found
# 11   = missing required script
# other = function executed with error
run_script (){
  local script="$1"
  local topic="${2:-$topic}"
  shift; shift
  local params=()
  local required=

  while [[ $# > 0 ]]; do
    case "$1" in
      -r | -required ) required="true" ;;
      * )  params+=("$1") ;;
    esac
    shift
  done

  log "-- run_script $script params: ${params[@]}"

  local status=0
  if [ -f "$script" ]; then

    # run the script
    sh "$script" ${params[@]}
    status=$?

    # script success
    if [ $status -eq 0 ]; then
      success "$(printf "Script executed %b%s%b on %b%s%b" $green "$script" $rc $green "$PLATFORM" $rc)"
      printf "success: %s\n" "$script" >> dotsys.log

    # script error
    else
      fail "$(printf "Script failed %b%s%b on %b%s%b." $red "$script" $rc $green "$PLATFORM" $rc)"
      printf "failed: %s\n" "$script" >> dotsys.log
    fi

  # missing required
  elif [ "$required" ]; then
    fail "$(printf "Script not found %b%s%b on %b%s%b" $green "$script" $rc $green "$PLATFORM" $rc)"
    printf "missing: %s\n" "$script" >> dotsys.log
    status=11

  # missing ok
  else
    printf "na: %s\n" "$script" >> dotsys.log
    status=10
  fi

  log "run_script exit [ $status ] for $script"

  return $status
}

# returns:
# 0     = everything ok
# 10   = script not found
# 11   = missing required script
# 12   = missing required function
# other = function executed with error
run_script_func () {
  local topic="$1"
  local file_name="$2"
  local action="$3"
  shift; shift; shift
  local params=()
  local required=

  while [[ $# > 0 ]]; do
    case "$1" in
      -r | -required ) required="true" ;;
      * )  params+=("$1") ;;
    esac
    shift
  done

  log "--- run_script_func recieved: $topic $file_name $action $required"

  # Returns built in and user script
  local scripts="$(get_topic_scripts "$topic" "$file_name")"

  # Verify required script was found
  if ! [ "$scripts" ] && [ "$required" ]; then
    fail "${file_name} is required for $topic"
    return 11
  fi
  local status=0
  # execute built in function then user script function
  for script in $scripts; do
      if script_func_exists $script $action; then
          log "running $script $action ${params[@]}"

          # run action & handle fail
          $script $action ${params[@]}
          status=$?

          # Required function failed
          if [ ! $status -eq 0 ] && [ "$required" ]; then
            fail "$(printf "%b%s%b could not $action %b%s%bwith %b%s%b" $green "$(cap_first $topic)" $rc $green "$params " $rc $green "$file_name " $rc )"

          # Success
          else
            success "$(printf "%b%s%b ${action}ed %b%s%bwith %b%s%b" $green "$(cap_first $topic)" $rc $green "$params " $rc $green "$file_name " $rc )"
          fi

      # Required script fail
      elif [ "$required" ]; then
          fail "$(printf "%b%s%b's %b%s%b file does not define the required %b%s%b function" $green "$(cap_first $topic)" $rc $green "$file_name " $rc $green "$action" $rc )"
          status=12
      # Silent fail when not required
      else
         status=10
      fi

  done

  log "run_script_func exit status [ $status ] for $script $action"

  return $status
}

get_topic_scripts () {
  local topic="$1"
  local file_name="$2"
  local exists=()

  local scripts=("$(builtin_topic_dir $topic)/${file_name}" "$(topic_dir $topic)/${file_name}")

  for path in ${scripts[@]}; do
      if [ -f "$path" ]; then
        exists+=("$path")
      fi
  done

  if ! [ "$exists" ]; then return 1;fi
  echo "${exists[@]}"
  return 0
}