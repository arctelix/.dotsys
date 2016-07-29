#!/bin/bash

# All functions pertaining to running scripts
# Author: arctelix

# RUN SCRIPT EXIT CODES: (run_script run_script_func)
# 0    = everything ok
# 10   = missing non-required script
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

  local rv=0

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
  rv=$?

  # Check for legacy script
  if [ $rv -ge 10 ] && [[ "install uninstall update upgrade" =~ $action ]]; then
     run_script_func "$topic" "$action.sh" "$action" $packages $required --legacy
     rv=$?
  fi

  debug "   -> run_topic_script EXIT STATUS [ $rv ]"

  return $rv
}

run_script_func () {
  local topic="$1"
  local script_name="$2"
  local action="$3"
  shift; shift; shift
  local params=()
  local required
  local legacy
  local scripts=()
  local rv=0

  while [[ $# > 0 ]]; do
    case "$1" in
      -r | -required ) required="required" ;;
      -l | --legacy ) legacy="(legacy)" ;;
      * )  params+=("$1") ;;
    esac
    shift
  done

  debug "-- run_script_func received t:$topic f:$script_name a:$action p:${params[@]} req:$required"

  # Returns builtin and user script
  local builtin_scr="$(topic_dir $topic "builtin")/${script_name}"
  local user_scr="$(topic_dir $topic "active")/${script_name}"
  local scripts=("${builtin_scr}")

  # catch duplicate from topic script
  if [ "$builtin_scr" != "$user_scr" ]; then
    scripts+=("$user_scr")
  else
    scripts+=("")
  fi

  # No need to run through scripts if they don't exist
  if ! [ -f "$builtin_scr" ] && ! [ -f "$user_scr" ];then
    debug "   run_script_func scripts $legacy: NOT FOUND"
    scripts=()
    if ! [ "$required" ];then
      rv=10
    else
      rv=11
    fi
  else
    debug "   run_script_func scripts $legacy:"
    debug "$(printf "   - %s\n" "${scripts[@]}")"
  fi

  local script_sources=(builtin user)
  local script_src
  local script
  local i=0
  local msg_prefix
  local msg_executed
  local msg_missing=()
  local executed

  # execute builtin then user script
  for script in "${scripts[@]}"; do

    script_src="${script_sources[$i]}"
    i=$((i+1))

    debug "   run_script_func $script_src $legacy: $script"

    # At this point we know at least one script exists so skip any non-existing
    if ! script_exists "$script";then
      continue

    elif ! [ "$legacy" ] && ! script_func_exists "$script" "$action"; then
      rv=12
      msg_missing+=("Missing $script_src $script_name $action function")
      continue
    fi

    # Freeze and return (one freeze is enough)
    if [ "$action" = "freeze" ]; then
      local result
      result="$("$script" "$action" ${params[*]})"
      freeze_msg "script" "$script" "$result"
      return
    fi

    # Legacy warning
    if [ "$legacy" ]; then
        warn "$topic/$script_name is a legacy script, it's contents should
      $spacer be added to $topic/topic.sh in a function named $action"
        get_user_input "Are you sure you want to run $topic/$script_name?" -r -d no
        if ! [ $? -eq 0 ]; then return;fi
    fi

    # run script
    if ! dry_run; then
      debug "   RUNNING SCRIPT ${legacy:-function} $script_src: $script $action ${params[*]}"

      if [ "$legacy" ]; then
        output_script "$script" ${params[*]}
      else
        output_script "$script" "$action" ${params[*]}
      fi
      rv=$?
    fi

    # manager message
    if [ "$script_name" = "manager.sh" ]; then
      msg_prefix="$DRY_RUN ${params:-\b} with"
      msg_executed="\b's $script_src"

    # topic message
    else
      msg_prefix="$DRY_RUN"
      msg_executed="${params:-\b} with $script_src"
    fi

    executed=$rv
    success_or_fail $rv "$action" "$msg_prefix" "$(printf "%b$topic" "$hc_topic")" "$msg_executed" "$script_name" "script $legacy"

  done

  # Fail on missing required script
  if [ "$required" ] && ! [ "$executed" ]; then
    ! [ "$msg_missing" ] && msg_missing=("Required $script_name script was not found")
    for msg in "${msg_missing[@]}";do
      fail "$msg"
    done
  fi

  debug "   run_script_func EXIT STATUS: $DRY_RUN[ ${executed:-$rv} ] for $script_name $action"

  return ${executed:-$rv}
}

get_topic_scripts () {
  local topic="$1"
  local file_name="$2"
  local exists=


  local script
  for script in ${scripts[@]}; do
      debug "   > checking for  $script"
      if [ -f "$script" ]; then
        exists="true"
        echo "$script"
      else
        echo ""
      fi
  done

  if ! [ "$exists" ]; then return 1;fi
  return 0
}