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

  # undamaged topic scripts need to check if already installed (since there likely installing software)
  # managed topic install scripts are really post-install scripts (manager checks for prior install)
  if ! is_managed && [ ! "$force" ]; then
      debug "   run_topic_script un-managed topic: checking install status"
      # check if already installed (not testing for repo!)
      if [ "$action" = "install" ] && is_installed "dotsys" "$topic" "$(get_active_repo)" --script ; then
        debug "  aborted unmanned topic script"
        continue
      # check if already uninstalled (not testing for repo!)
      elif [ "$action" = "uninstall" ] && ! is_installed "dotsys" "$topic" "$(get_active_repo)" --script; then
        debug "  aborted unmanned topic script"
        continue
      fi
      debug "   run_topic_script un-managed topic: ok to proceed with script"
  fi

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
     #success "$(printf "No $action script supplied $DRY_RUN for %b$topic%b" $green $rc)"
     pass
  fi

  # record success to state file (10 = not found, but not required)
  if [ $status -le 10 ]; then # success
      # installed
      if [ "$action" = "install" ]; then
            # add to state file if not there
            state_install "dotsys" "$topic" "$(get_active_repo)"
            INSTALLED+=($topic) # not used any more
      # uninstalled
      elif [ "$action" = "uninstall" ]; then
          # remove topic form state file
          state_uninstall "dotsys" "$topic" "$(get_active_repo)"
          INSTALLED=( "${INSTALLED[@]/$topic}" ) # not used any more
      fi
  fi

  return $status
}

# 0     = everything ok
# 10   = script not found
# 11   = missing required script
# other = function executed with error
# ONLY CHECKS TOIC DIRECTORY
run_script (){
  local topic="${1:-$topic}"
  local action="${2:-$action}"
  shift; shift
  local script="$(topic_dir "$topic")/${action}.sh"
  local params=()
  local required=
  local result

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

    if [ "$action" = "freeze" ]; then
      result="$(sh "$script" ${params[@]})"
      if [ "$result" ]; then
        freeze_msg "script" "$script" "$result"
      fi
      return
    #run the script
    elif ! dry_run;then
      script -q /dev/null "$script" ${params[@]} | indent_lines
      status=$?
    fi

    success_or_fail $status "exicute" "script $DRY_RUN" "$(printf "%b$script" $thc )" "on" "$(printf "%b$PLATFORM" $thc)"

  # missing required
  elif [ "$required" ]; then
    fail "Script not found $DRY_RUN" "$(printf "%b$script" $thc )" "on" "$(printf "%b$PLATFORM" $thc)"
    status=11

  # missing ok
  else
    status=10
  fi

  debug "   run_script exit status $DRY_RUN[ $status ] for $script"

  return $status
}


# 0    = everything ok
# 10   = script not found
# 11   = missing required script
# 12   = missing required function
# other = function executed with error
run_script_func () {
  local topic="$1"
  local script_name="$2"
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

  debug "-- run_script_func received : t:$topic f:$script_name a:$action p:${params[@]} req:$required"

  # Returns built in and user script
  local scripts="$(get_topic_scripts "$topic" "$script_name")"

  # Verify required script was found
  if ! [ "$scripts" ] && [ "$required" ]; then
    fail "${script_name} is required for $topic"
    return 11
  fi

  local status=0

  # execute built in function then user script function
  local script_sources=(builtin $ACTIVE_REPO)
  local script_src
  local script
  local result
  local prefix
  local message
  local i=0
  for script in $scripts; do
      script_src="${script_sources[$i]}"
      debug "   run_script_func_src: $script_src $script"
      if script_func_exists "$script" "$action"; then

          debug "   running $script $action ${params[@]}"

          if [ "$action" = "freeze" ]; then
              result="$($script $action ${params[@]})"
              if [ "$result" ]; then
                freeze_msg "script" "$script" "$result"
              fi
              return
          # run script action func
          elif ! dry_run; then
            output_script "$script" "$action" ${params[@]}
            status=$?
          fi

          # manager message
          if [ "$script_name" = "manager.sh" ]; then
            prefix="$DRY_RUN ${params:-\b} with"
            message="'s $script_src"
          # other message
          else
            prefix="$DRY_RUN"
            message="${params:-\b} with $script_src"
          fi

          # Required function success/fail
          if [ "$required" ]; then
              success_or_fail $status "$action" "$prefix" "$(printf "%b$topic" $thc)" "$message" "$script_name"

          # Only show success for not required
          #elif [ $status -eq 0 ]; then
          # On second thought, this is helpful
          else
              success_or_fail $status "$action" "$prefix" "$(printf "%b$topic" $thc)" "$message" "$script_name"
          fi

      # Required script fail
      elif [ "$required" ]; then
          fail "$(cap_first "$script_name") $DRY_RUN for" "$topic"  "does not define the required $action function"
          status=12
      # Silent fail when not required
      else
         status=10
      fi

      i=$((i+1))

  done

  debug "   run_script_func exit status: $DRY_RUN[ $status ] for $script $action"

  return $status
}

get_topic_scripts () {
  local topic="$1"
  local file_name="$2"
  local exists=
  local builtin_script="$(builtin_topic_dir $topic)/${file_name}"
  local topic_script="$(topic_dir $topic "user")/${file_name}"
  local scripts=("$builtin_script")

  # catch duplicate from topic script
  debug "  -get_topic_scripts builtin: $builtin_script"
  debug "  -get_topic_scripts topic_script: $topic_script"
  if [ "$builtin_script" != "$topic_script" ]; then
    scripts+=("$topic_script")
  fi

  local path
  for path in ${scripts[@]}; do
      if [ -f "$path" ]; then
        echo "$path"
        exists="true"
      fi
  done

  if ! [ "$exists" ]; then return 1;fi
  return 0
}