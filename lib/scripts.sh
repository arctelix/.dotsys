#!/bin/bash

# All functions pertaining to running scripts
# Author: arctelix

# RUN SCRIPT EXIT CODES: (run_script run_script_func)
# 0    = everything ok
# 10   = non required script not found
# 11   = missing required script
# 12   = missing required script function

# EXTERNAL SCRIPT EXIT CODES
# 20    = task complete: do not print success/fail msg
# 21    = task incomplete: do not print success/fail msg


# other = function executed with error


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

  local state=0

  # un-managed topic scripts need to check if already installed (since there likely installing software)
  # managed topic install scripts are really post-install scripts (manager checks for prior install)
  if ! is_managed && [ ! "$force" ]; then

      # check if already installed (not testing for repo!)
      if [ "$action" = "install" ] && is_installed "dotsys" "$topic" "$(get_active_repo)" --script ; then
        debug "  aborted unmanaged topic script"
        return

      # check if already uninstalled (not testing for repo!)
      elif [ "$action" = "uninstall" ];then

        # In use by active repo
        if ! is_installed "dotsys" "$topic" "$(get_active_repo)" --script; then
            debug "  aborted unmanaged topic script"
            return

        # Catch uninstall required topic (force not permitted)
        # Checks depts state for dotsys topic dependants
        elif topic_in_use "$topic" "dotsys/dotsys" && ! in_limits "dotsys" -r; then
            warn "Skipped uninstall script for required topic: $topic"
            return
        fi
      fi
      debug "   run_topic_script un-managed topic: ok to proceed with script"
  fi

  run_script_func "$topic" "topic.sh" "$action" $packages $required
  state=$?

  # no script required for topic
  if [ $state -eq 10 ]; then
     #success "$(printf "No $action script supplied $DRY_RUN for %b$topic%b" $green $rc)"
     pass
  fi

  return $state
}


# DEPRECIATED (merged with run_script_func)
xxrun_script (){
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

  local state=0

  if script_exists "$script"; then

    if [ "$action" = "freeze" ]; then
      result="$(sh "$script" ${params[@]})"
      if [ "$result" ]; then
        freeze_msg "script" "$script" "$result"
      fi
      return
    #run the script
    elif ! dry_run;then
      output_script "$script" ${params[*]}
      state=$?
    fi

    success_or_fail $state "exicute" "script $DRY_RUN" "$(printf "%b$script" "$hc_topic" )" "on" "$(printf "%b$PLATFORM" "$hc_topic")"

  # missing required
  elif [ "$required" ]; then
    fail "Script not found $DRY_RUN" "$(printf "%b$script" "$hc_topic" )" "on" "$(printf "%b$PLATFORM" "$hc_topic")"
    state=11

  # missing ok
  else
    state=10
  fi

  debug "   run_script exit status $DRY_RUN[ $state ] for $script"

  return $state
}


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
  local scripts=( $(get_topic_scripts "$topic" "$script_name") )
  debug "   run_script_func scripts:
  ${scripts[@]}"

  # Verify required script was found
  if ! [ "$scripts" ] && [ "$required" ]; then
    fail "${script_name} is required for $topic"
    return 11
  fi

  local rv=0
  local script_sources=(builtin active)
  local script_src
  local script
  local prefix
  local message
  local result
  local i=0

  # execute built in function then user script function
  for script in ${scripts[@]}; do

    script_src="${script_sources[$i]}"
    i=$((i+1))

    debug "   run_script_func src: ($script_src) $script"

    legacy=""
    if ! script_exists "$script"; then
      # Check for legacy script
      script="$(topic_dir "$topic" "$script_src")/${action}.sh"
      legacy="true"

    elif ! script_func_exists "$script" "$action"; then
      script=""
      rv=12
    fi

    if ! [ -f "$script" ];then

      # Display error message for required scripts
      if [ "$required" ]; then

        fail "$(cap_first "$script_name") $DRY_RUN for" "$topic"  "does not define the required $action function"
        rv=${rv:-11}

      # Silent fail when not required
      else
       rv=10
      fi
      continue
    fi

    # Freeze and return (one freeze is enough)
    if [ "$action" = "freeze" ]; then

      if [ "$legacy" ]; then
        result="$("$script" ${params[*]})"
      else
        result="$("$script" "$action" ${params[*]})"
      fi

      if [ "$result" ]; then
        freeze_msg "script" "$script" "$result"
      fi
      return
    fi

    # run script
    if ! dry_run; then
      debug "   running script func: $script $action ${params[*]}"
      if [ "$legacy" ]; then
        output_script "$script" ${params[*]}
      else
        output_script "$script" "$action" ${params[*]}
      fi
      rv=$?
    fi

    # manager message
    if [ "$script_name" = "manager.sh" ]; then
      prefix="$DRY_RUN ${params:-\b} with"
      message="'s $script_src"

    # topic message
    else
      prefix="$DRY_RUN"
      message="${params:-\b} with $script_src"
    fi

    # Required function success/fail
    if [ "$required" ]; then
      success_or_fail $rv "$action" "$prefix" "$(printf "%b$topic" "$hc_topic")" "$message" "$script_name"

    # Only show success for not required
    #elif [ $status -eq 0 ]; then
    # On second thought, this is helpful
    else
      success_or_fail $rv "$action" "$prefix" "$(printf "%b$topic" "$hc_topic")" "$message" "$script_name"
    fi

  done

  debug "   run_script_func exit status: $DRY_RUN[ $rv ] for $script $action"

  return $rv
}

get_topic_scripts () {
  local topic="$1"
  local file_name="$2"
  local exists=
  local builtin_script="$(topic_dir $topic "builtin")/${file_name}"
  local topic_script="$(topic_dir $topic "active")/${file_name}"
  local scripts=("$builtin_script")

  debug "  -get_topic_scripts builtin: $builtin_script"
  debug "  -get_topic_scripts topic_script: $topic_script"

  # catch duplicate from topic script
  if [ "$builtin_script" != "$topic_script" ]; then
    scripts+=("$topic_script")
  fi

  local path
  for path in ${scripts[@]}; do
      if [ -f "$path" ]; then
        exists="true"
        echo "$path"
      else
        echo ""
      fi

  done

  if ! [ "$exists" ]; then return 1;fi
  return 0
}