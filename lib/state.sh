#!/usr/bin/env bash

state_dir () {
  echo "$(dotsys_dir)/state"
}

# adds key:value if key:value does not exist (value optional)
state_install() {
  local file="$(state_dir)/${1}.state"
  local key="$2"
  local value="$3"

  #if ! [ -f "$file" ]; then touch "$file"; fi
  grep -q "${key}:${value}" "$file" || echo "${key}:${value}" >> "$file"
}

# removes key:value if key and value exist (value optional)
state_uninstall () {
  local file="$(state_dir)/${1}.state"
  local key="$2"
  local value="$3"

  #if ! [ -f "$file" ]; then touch "$file"; fi
  grep -v "${key}:${value}" "$file" > "temp.state" && mv "temp.state" "$file"
}

# test if topic is already on system or installed by dotsys
is_installed () {
  local state="$1"
  local key="$2"
  local value="$3"

  local file="$(state_dir)/${state}.state"
  debug "is_installed k:$key v:$value"

  # test for manager (this was a stupid test i think)
  #  local manager="$(get_topic_manager "$key")"
  #  local manager_test="$(get_topic_config_val "$manager" "installed_test")"
  #  if cmd_exists "${manager_test:-$topic}"; then return 0; fi

  # test key is a command
  local installed_test="$(get_topic_config_val "$key" "installed_test")"
  if cmd_exists "${installed_test:-$topic}"; then return 0; fi

  #TODO: implement test for installed from repo or version?

  # test if in state file
  in_state "$state" "$key" "$value"

  return $?
}

# Test if key (optional value) exists in state file
in_state () {
  local file="$(state_dir)/${1}.state"
  local key="$2"
  local value="$3"

  # test if topic is listed in state file
  #if ! [ -f "$file" ]; then touch "$file"; fi
  grep -q "${key}:$value" "$file"
}

# gets value for unique key
get_state_value () {
  local key="$1"
  local file="$(state_dir)/${2:-dotsys}.state"
  local result="$(grep "^$key:.*$" "$file")"
  echo "${result#*:}"
}

# sets value for unique key
set_state_value () {
  local key="$1"
  local value="$2"
  local file="${3:-dotsys}"
  state_uninstall "$file" "$key"
  state_install "$file" "$key" "$value"
}

# sets / gets primary repo value
state_primary_repo(){
  local repo="$1"
  local key="user_repo"

  if [ "$repo" ]; then
    set_state_value "$key" "$repo"
  else
    echo "$(get_state_value "$key")"
  fi
}

# get list of existing state names
get_state_list () {
    local file_paths="$(find "$(state_dir)" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')"
    local state_names=
    local p
    for p in ${file_paths[@]}; do
        local file_name="$(basename "$p")"
        echo "${file_name%.*} "
    done
}
