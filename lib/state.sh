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
# if no value is supplied also checks if installed on system
is_installed () {
    local state="$1"
    local key="$2"
    shift;shift
    local val

    usage="is_installed <state> <key> [<val>] [<option>]"
    usage_full="
        -m | --manager        Use manager warnings
        -m | --manager        Use scripts warnings
    "
    local manager
    local script
    while [[ $# > 0 ]]; do
        case "$1" in
        -m | --manager )      manager="$1" ;;
        -s | --script )      script="$1" ;;
        *)  uncaught_case "$1" "state" "key" "val" ;;
        esac
        shift
    done

    local installed=1
    local system_ok

    debug "-- is_installed got: $state ($key:$var) $manager"

    # if state is "system" then a system install is acceptable
    # so bypass warnings and just return 0
    if [ "$state" = "system" ]; then
        state="dotsys"
        system_ok="true"
    fi

    # test if in specified state file
    in_state "$state" "$key" "$val"
    installed=$?

    debug "   is_installed in: $state = $installed"

    # Check if installed on system, not managed by dotsys
    if ! [ "$installed" -eq 0 ]; then
        local installed_test="$(get_topic_config_val "$key" "installed_test")"

        # installed on system
        if cmd_exists "${installed_test:-$key}"; then

            # System installed is ok
            if [ "$system_ok" = "true" ]; then
                installed=0

            # manager warnings
            elif [ "$manager" ]; then
                if [ "$action" = "uninstall" ]; then
                    warn "Can not uninstall" "$key's" "package" "$(printf "%bit was not installed by dotsys." $red)" \
                    "\n$spacer You will have to uninstall it by whatever means it was installed."
                    installed=1
                elif ! [ "$force" ]; then
                    warn "Although" "$key's" "package is installed," "$(printf "%bit was not installed by dotsys." $red)" \
                    "$(printf "\n$spacer Use %bdotsys install $key --force%b to allow dotsys to manage it" $code $yellow)"
                    installed=0
                fi

            # script warnings
            elif [ "$script" ]; then
                if [ "$action" = "uninstall" ]; then
                    # not installed by dotsys so skip uninstall script
                    installed=1
                elif ! [ "$force" ]; then
                    warn "It appears that" "$key" "$(printf "was already installed on this system" $red)" \
                    "$(printf "\n$spacer Use %bdotsys install $key --force%b to run the dotsys install script" $code $yellow)"
                    installed=0
                fi
            fi
            debug "   is_installed by other means -> $installed"

        # not installed on system
        else
            installed=1
            debug "   not installed on system -> $installed"
        fi
    fi

    debug "   is_installed ($key:$val) final -> $installed"

    return $installed
}

# Test if key and or value exists in state file
# use "!$key" to negate keys containing "$key"
# use "!$val" to negate values containing "$val"
# ie: key="!repo" will not match keys "user_repo:" or "repo:" etc..
in_state () {
  local state="$1"
  local file="$(state_file "$state")"
  if ! [ -f "$file" ]; then return 1;fi
  local key="$2"
  local val="$3"
  in_state_results=
  local not_key="$key"
  local not_val="$val"
  local not
  local r

  debug "   - in_state check '$state' for '$key:$val'"

  if [[ "$key" == "!"* ]]; then
    not_key="${key#!}.*"
    key=""
    not="true"
  fi
  if [[ "$val" == "!"* ]]; then
    not_val=".*${val#!}"
    val=""
    not="true"
  fi

  in_state_results="$(grep "$(grep_kv)" "$file")"
  local status=$?
  debug "     in_state grep '$(grep_kv)' = $status"
  debug "     in_state grep result:$(echo "$in_state_results" | indent_lines)"

  if [ "$not" ]; then
      for r in $in_state_results; do
        if [ "$r" ] && ! [[ "$r" =~ ${not_key}:${not_val} ]]; then
            debug "$indent -> testing $r !=~ '${not_key}:${not_val}' = 0"
            return 0
        fi
        debug "$indent -> testing $r !=~ '${not_key}:${not_val}' = 1"
      done
      return 1
  fi

  debug "$indent -> in_state = $status"
  return $status
}

# gets value for unique key
get_state_value () {
  local file="$(state_file "$1")"
  local key="$2"
  local match_val="$3"
  local status=0

  local lines="$(grep "^$key:.*$" "$file")"
  status=$?
  local val="${lines#*:}"



  debug "   - get_state_value found: $lines"

  if [ "$val" = "1" ] || [ "$val" = "0" ]; then
    status=$val
  elif [ "$val" ]; then
      local line
      for line in $lines; do
          val="${line#*:}"
          if [[ "$match_val" == "!"* ]]; then
              if ! [[ "$val" =~ ${match_val#!} ]]; then echo "$val"; fi
          elif [ "$match_val" ]; then
              if [[ "$val" =~ ${match_val} ]]; then echo "$val"; fi
          elif [ "$val" ]; then
              echo "$val"
          fi
      done
  fi
  return $status
}

# sets value for unique key
set_state_value () {
  local state="${1}"
  local key="$2"
  local val="$3"

  state_uninstall "$state" "$key"
  state_install "$state" "$key" "$val"
}

# sets / gets primary repo value
state_primary_repo(){
  local repo="$1"
  local key="user_repo"

  if [ "$repo" ]; then
    set_state_value "user" "$key" "$repo"
  else
    echo "$(get_state_value "user" "$key")"
  fi
}

# get list of existing state names
get_state_list () {
    local file_paths="$(find "$(state_dir)" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')"
    local state_names=
    local p
    for p in ${file_paths[@]}; do
        local file_name="$(basename "$p")"
        echo "${file_name%.state} "
    done
}

freeze_states() {

    freeze_state "user"
    freeze_state "dotsys"
    freeze_state "repos"

    local s
    for s in $(get_state_list); do
        if is_manager "$s"; then
            freeze_state "$s"
        fi
    done
}

freeze_state() {
    local state="$1"
    local file="$(state_file "$state")"
    if ! [ -s "$file" ]; then return;fi

    task "Freezing" "$(printf "%b$state state:" $thc)"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        #echo " - $line"
        freeze_msg "${line%:*}" "${line#*:}"

    done < "$file"
}

get_topic_list () {
    local from_repo="${1}"
    local active_repo="$(get_active_repo)"
    local repo_dir="$(repo_dir "${from_repo:-$active_repo}")"
    local force="$2"
    local list
    local topic
    local repo

    debug "-- get_topic_list: from:$from_repo active_repo:$active_repo"

    if is_dotsys_repo "$active_repo"; then
        # no force permitted for dotsys repo
        force=
        # USE BUILTIN TOPICS FOR DOTSYS
        repo_dir="$DOTSYS_REPOSITORY/builtins"
    fi

    # only installed topics when not installing unless forced or from
    if [ "$action" != "install" ] && ! [ "$force" ]; then
        while read -r line || [ "$line" ]; do
            topic=${line%:*}
            repo=${line#*:}

            debug "   get_topic_list found ($topic:$repo)"

            # do not uninstall dotsys topics unless in limits
            if [ "$action" = "uninstall" ] && ! in_limits "dotsys" -r && is_dotsys_repo "$repo"; then continue

            # limit topics to from repo
            elif [ "$from_repo" ] && [ "$from_repo" != "$repo" ]; then continue;fi

            echo "$topic"
        done < "$(state_file "dotsys")"
    # all defined topic directories
    else
        if ! [ -d "$repo_dir" ];then return 1;fi
        get_dir_list "$repo_dir"
    fi
}

get_installed_topic_paths () {
    local list
    local topic
    local repo

    while read line; do
        topic=${line%:*}
        repo=${line#*:}
        # skip system keys
        if [[ "$STATE_SYSTEM_KEYS" =~ $topic ]]; then continue; fi

        if [ "$repo" = "dotsys/dotsys" ]; then
            repo="$DOTSYS_REPOSITORY/builtins"

        else
            repo="$(dotfiles_dir)/$repo"
        fi

        if [ -d "$repo/$topic" ]; then
            echo "$repo/$topic"
        fi

    done < "$(state_file "dotsys")"
}