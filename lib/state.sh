#!/usr/bin/env bash

state_dir () {
  echo "$(dotsys_dir)/state"
}

state_file () {
    echo "$(state_dir)/${1}.state"
}
# adds key:value if key:value does not exist (value optional)
state_install() {
  local file="$(state_file "$1")"
  local key="$2"
  local val="$3"

  if ! [ -f "$file" ]; then return 1;fi

  grep -q "$(grep_kv)" "$file" || echo "${key}:${val}" >> "$file"
}

# removes key:value if key and value exist (value optional)
state_uninstall () {
  local file="$(state_file "$1")"
  local temp="$(state_dir)/temp_$1.state"
  local key="$2"
  local val="$3"



  if ! [ -f "$file" ]; then return 1;fi
  debug "   - state_uninstall: f:$file grep ${key}:${val}"

  # grep -v fails on last item so we have to test then remove
  grep -q "$(grep_kv)" "$file"
  if [ $? -eq 0 ]; then
     debug "   - state_uninstall FOUND ${key}:${value}, uninstalling"
     grep -v "$(grep_kv)" "$file" > "$temp"
     mv -f "$temp" "$file"
  else
     debug "   - state_uninstall NOT FOUND: f:$file grep ${key}:${val}"
  fi


}

grep_kv (){
    local k
    local v
    if [ "$val" ];then  v="${val}\$"; else v="$val"; fi
    if [ "$key" ];then  k="^${key}"; else k="$key" ;fi
    echo "${k}:${v}"
}


# test if key and or value exists in state
# if key is a topic run installed_test to see if exits on system
is_installed () {
    local state="$1"
    local key="$2"
    local val="$3"

    local installed=1
    local manager=

    # test if in specified state file
    in_state "$state" "$key" "$val"
    installed=$?
    debug "   - is_installed in $state: $installed"

    # Check if installed by manager ( packages installed via package.yaml file )
    if [ "$state" = "dotsys" ] && ! [ "$installed" -eq 0 ]; then
        local manager="$(get_topic_manager "$key")"
        in_state "$manager" "$key" "$val"
        installed=$?
        debug "   - is_installed in ${manager:-not managed}: $installed"
    fi

    # Check if installed on system, not managed by dotsys
    if ! [ "$installed" -eq 0 ]; then
        local installed_test="$(get_topic_config_val "$key" "installed_test")"
        if cmd_exists "${installed_test:-$key}"; then
            if [ "$action" = "uninstall" ]; then
                warn "$(printf "Although %b$key is installed%b, it was not installed by dotsys.
                $spacer You will have to %buninstall it by whatever means it was installed.%b" $green $rc $yellow $rc) "
                installed=1
            elif ! [ "$force" ]; then
                warn "$(printf "Although %b$key is installed%b, it is not managed by dotsys.
                $spacer Use %bdotsys install $key --force%b to allow dotsys to manage it." $green $rc $yellow $rc)"
                installed=0
            fi
        fi
        debug "   - is_installed by other means: $installed"
    fi

    debug "   - is_installed $key:$val final: $installed"

    return $installed
}

# Test if key and or value exists in state file
# use "!$key" to negate values with keys that contain "$key"
# ie: key="!repo" will not match keys "user_repo:" or "repo:" etc..
in_state () {
  local state="$1"
  local file="$(state_file "$state")"
  if ! [ -f "$file" ]; then return 1;fi
  local key="$2"
  local val="$3"
  local results
  local not
  local r

  if [[ "$key" == "!"* ]]; then
      not="${key#!}"
      key=""
      results="$(grep -q "$(grep_kv)" "$file")"
      for r in $results; do
        #debug "   - in_state: result for !$not ${key}:$value  = $r"
        if [ "$r" ] && ! [[ "$r" =~ ${not}.*:${value} ]]; then
            return 0
        fi
      done
      return 1
  fi

  # test if key and or value is in state file
  debug "   in_state grep '$(grep_kv)' from file: $file"
  grep -q "$(grep_kv)" "$file"
}

# gets value for unique key
get_state_value () {
  local key="$1"
  local file="$(state_file "${2:-dotsys}")"
  local results="$(grep "^$key:.*$" "$file")"
  echo "${results#*:}"
}

# sets value for unique key
set_state_value () {
  local key="$1"
  local val="$2"
  local state="${3:-dotsys}"
  state_uninstall "$state" "$key"
  state_install "$state" "$key" "$val"
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
