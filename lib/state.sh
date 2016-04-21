#!/usr/bin/env bash

state_dir () {
  echo "$(dotsys_dir)/state"
}

state_install() {
  local file="$(state_dir)/${1:-dotsys}.state"
  local key="$2"
  local value="$3"

  if ! [ -f "$file" ]; then touch "$file"; fi
  grep -q "^${key}[^\w\s\d]" "$file" || echo "${key}:${value}" >> "$file"
}

state_uninstall () {
  local file="$(state_dir)/${1:-dotsys}.state"
  local key="$2"

  if ! [ -f "$file" ]; then touch "$file"; fi
  grep -v "^${key}[^\w\s\d]" "$file" > "temp.state" && mv "temp.state" "$file"
}

is_installed () {
  local topic="$1"
  local state="${2:-dotsys}"
  local file="$(state_dir)/${state}.state"

  # test if command exists on system
  local manager="$(get_topic_manager "$topic")"
  local manager_test="$(get_topic_config_val "$manager" "installed_test")"
  if cmd_exists "${manager_test:-$topic}"; then return 0; fi
  local installed_test="$(get_topic_config_val "$topic" "installed_test")"
  if cmd_exists "${installed_test:-$topic}"; then return 0; fi

  # test if topic is listed in state file
  in_state "$topic" "$state"
  return $?
}

in_state () {
  local key="$1"
  local file="$(state_dir)/${2:-dotsys}.state"
  # test if topic is listed in state file
  if ! [ -f "$file" ]; then touch "$file"; fi
  grep -q "^${key}[^\w\s\d]" "$file"
}

get_state_value () {
  local key="$1"
  local file="$(state_dir)/${2:-dotsys}.state"
  local result="$(grep "^$key:.*$" "$file")"
  echo "${result#*:}"
}

set_state_value () {
  local key="$1"
  local value="$2"
  local file="${3:-dotsys}"
  state_uninstall "$file" "$key"
  state_install "$file" "$key" "$value"
}

# sets state repo or returns repo value
state_repo(){
  local repo="$1"
  local key="user_repo"

  if [ "$repo" ]; then
    set_state_value "$key" "$repo"
  else
    echo "$(get_state_value "$key")"
  fi
}