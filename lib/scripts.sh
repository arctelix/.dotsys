#!/bin/sh

# All functions pertaining to running scripts
# Author: arctelix


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

  debug "-- run_topic_script $action for $topic $required"

  local status=0

  # try topic.sh function call first
  if [ -f "$(topic_dir "$topic")/topic.sh" ];then
    run_script_func "$topic" "topic.sh" "$action" $packages $required
    status=$?

  # run individual action scripts
  else
    run_script "$topic" "$action" $packages $required
    status=$?
  fi

  # no script required for topic
  if [ $status -eq 10 ]; then
     success "$(printf "No $action script supplied %sfor %b$topic%b" "$DRY_RUN" $light_green $rc)"
  fi

  # record success to state file (10 = not found, but not required)
  if [ $status -le 10 ]; then # success
      # installed
      if [ "$action" = "install" ]; then
            # add to state file if not there
            state_install "dotsys" "$topic" "$ACTIVE_REPO"
            INSTALLED+=($topic) # not used any more
      # uninstalled
      elif [ "$action" = "uninstall" ]; then
          # remove topic form state file
          state_uninstall "dotsys" "$topic" "$ACTIVE_REPO"
          INSTALLED=( "${INSTALLED[@]/$topic}" ) # not used any more
      fi
  fi

  #return $status
}

# runs a specified script, and displays status, and debugs
# 0     = everything ok
# 10   = script not found
# 11   = missing required script
# other = function executed with error
run_script (){
  local topic="${1:-$topic}"
  local action="${2:-$action}"
  shift; shift
  local script="$(topic_dir "$topic")/${action}.sh"
  local params=()
  local required=

  while [[ $# > 0 ]]; do
    case "$1" in
      -r | -required ) required="true" ;;
      * )  params+=("$1") ;;
    esac
    shift
  done

  debug "-- run_script $script params: ${params[@]}"

  local status=0

  if script_exists "$script"; then
    # run the script
    if ! [ "$DRY_RUN" ];then
      sh "$script" ${params[@]}
      status=$?
    fi

    # script success
    if [ $status -eq 0 ]; then
      success "$(printf "Script executed %s%b%s%b on %b%s%b" "$DRY_RUN" $green "$script" $rc $green "$PLATFORM" $rc)"
      printf "success: %s\n" "$script" >> $DEBUG_FILE

    # script error
    else
      fail "$(printf "Script failed %s%b%s%b on %b%s%b." "$DRY_RUN" $red "$script" $rc $green "$PLATFORM" $rc)"
      printf "failed: %s\n" "$script" >> $DEBUG_FILE
    fi

  # missing required
  elif [ "$required" ]; then
    fail "$(printf "Script not found %s%b%s%b on %b%s%b" "$DRY_RUN" $green "$script" $rc $green "$PLATFORM" $rc)"
    printf "missing: %s\n" "$script" >> $DEBUG_FILE
    status=11

  # missing ok
  else
    printf "na: %s\n" "$script" >> $DEBUG_FILE
    status=10
  fi

  debug "   run_script exit status $DRY_RUN[ $status ] for $script"

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

  debug "-- run_script_func received : t:$topic f:$file_name a:$action p:${params[@]} req:$required"

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
      if script_func_exists "$script" "$action"; then

          debug "   running $script $action ${params[@]}"

          # run action & handle fail
          if ! [ "$DRY_RUN" ]; then
            $script $action ${params[@]}
            status=$?
          fi

          # Required function failed
          if [ ! $status -eq 0 ] && [ "$required" ]; then
            fail "$(printf "%b%s%b could not $action %s%b%s%bwith %b%s%b" $green "$(cap_first $topic)" $rc "$DRY_RUN" $green "$params " $rc $green "$file_name " $rc )"

          # Success
          else
            success "$(printf "%b%s%b ${action}ed %s%b%s%bwith %b%s%b" $green "$(cap_first $topic)" $rc "$DRY_RUN" $green "$params " $rc $green "$file_name " $rc )"
          fi

      # Required script fail
      elif [ "$required" ]; then
          fail "$(printf "%b%s%b's %s%b%s%b file does not define the required %b%s%b function" $green "$(cap_first $topic)" $rc "$DRY_RUN" $green "$file_name " $rc $green "$action" $rc )"
          status=12
      # Silent fail when not required
      else
         status=10
      fi

  done

  debug "   run_script_func exit status: $DRY_RUN[ $status ] for $script $action"

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