#!/bin/sh

state_dir () {
  echo "$DOTSYS_REPOSITORY/state"
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

    local usage="is_installed <state> <key> [<val>] [<option>]"
    local usage_full="
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
  local query="$key:$val"
  local not
  local r

  #debug "   - in_state check '$state' for '$key:$val'"

  if [[ "$key" == "!"* ]]; then
    not="not"
    not_key="${key#!}.*"
    key=""
  fi
  if [[ "$val" == "!"* ]]; then
    not="not"
    not_val=".*${val#!}"
    val=""
  fi

  in_state_results="$(grep "$(grep_kv)" "$file")"
  local ret=$?

  local found
  if [ "$not" ]; then
      ret=1
      for r in $in_state_results; do
        #debug "$indent -> testing $r !=~ '${not_key}:${not_val}' = $status"
        if [ "$r" ] && ! [[ "$r" =~ ${not_key}:${not_val} ]]; then
            ret=0
            in_state_results="$r"
            #debug "$indent -> found $r"
            break
        fi
      done
  fi

  debug "   - in_state ($query) = $ret $in_state_results"
  return $ret
}

# gets value for provided key
# optionally restrict to value or ! match value
get_state_value () {
  local file="$(state_file "$1")"
  local key="$2"
  local match_val="$3"
  local ret=0

  # State file does not exist yet so pretend it's ok (pre install)
  if ! [ -f "$file" ]; then return 0;fi
  debug "   - get_state_value grep: ^$key:.*$:"
  local lines
  lines=($(grep "^$key:.*$" "$file"))
  ret=$?
  local val="${lines#*:}"
  #debug "   - get_state_value lines: $lines"

  if [ "$val" = "1" ] || [ "$val" = "0" ]; then
    ret=$val

  elif [ "$val" ]; then
      local line
      ret=1
      for line in ${lines[@]}; do
          val="${line#*:}"

          # do not match the provided value
          if [[ "$match_val" == "!"* ]]; then
              if ! [[ "$val" =~ ${match_val#!} ]]; then
                echo "$val"
                ret=0
              fi

          # only match the provided value
          elif [ "$match_val" ]; then
              if [[ "$val" =~ ${match_val} ]]; then
                echo "$val"
                ret=0
              fi

          elif [ "$val" ]; then
              echo "$val"
              ret=0
          fi
      done
  fi

  debug "   - get_state_value found lines: ${lines[*]}
     -> exit code = $ret | val =  $val"

  return $ret
}

# sets value for unique key
set_state_value () {
  local state="${1}"
  local key="$2"
  local val="$3"

  state_uninstall "$state" "$key"
  state_install "$state" "$key" "$val"
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

    task "Freezing" "$(printf "%b$state state:" $hc_topic)"
    while IFS='' read -r line || [[ -n "$line" ]]; do
        #echo " - $line"
        freeze_msg "${line%:*}" "${line#*:}"

    done < "$file"
}

get_topic_list () {
    local from_repo="$1"

    if [ "$from_repo" = "none" ]; then
        from_repo=""
    fi

    local active_repo="$(get_active_repo)"
    local repo_dir="$(repo_dir "${from_repo:-$active_repo}")"
    local force="$2"
    local repo

    debug "-- get_topic_list: from:$from_repo active_repo:$active_repo"

    if is_dotsys_repo "$active_repo"; then
        # no force permitted for dotsys repo
        force=
        # USE BUILTIN TOPICS FOR DOTSYS
        repo_dir="$DOTSYS_REPOSITORY/builtins"
    fi

    # Return all installed topics for all other actions
    if [ "$action" != "install" ] && ! [ "$force" ]; then
        local topics=()
        local line
        local topic
        local skip
        while read -r line || [ "$line" ]; do
            topic=${line%:*}
            repo=${line#*:}
            skip=""

            # Check for duplicate topic from dotsys & user repo
            if [[ "${topics[*]}" =~ $topic ]];then
                skip="topic redundant"

            # do not uninstall dotsys topics unless in limits
            elif [ "$action" = "uninstall" ] && ! in_limits "dotsys" -r && is_dotsys_repo "$repo"; then
                skip="dotsys repo"

            # limit topics to from repo
            elif [ "$from_repo" ] && [ "$from_repo" != "$repo" ]; then
                skip="other repo"
            fi

            if [ "$skip" ]; then
                debug "   get_topic_list: skipped $skip ($topic:$repo)"
                continue
            fi

            debug "   get_topic_list: added ($topic:$repo)"
            echo "$topic"
            topics+=("$topic")
        done < "$(state_file "dotsys")"

    # Catch no repo directory
    elif ! [ -d "$repo_dir" ];then
        return 1

    # Install from repo directory
    else
        if ! [ -d "$repo_dir" ];then return 1;fi

        # dotsys install limited to shell & deps
        if in_limits "dotsys" -r; then
            echo "core"

        # all other installs take topic directory
        else
            get_dir_list "$repo_dir"
        fi
    fi
}

# returns list of installed topics
# format options:
#   dir : absoute path to topic directory
get_installed_topics () {
    local format="$1"
    local list
    local topic
    local repo

    while read line; do
        topic=${line%:*}
        repo=${line#*:}

        if [ "$repo" = "dotsys/dotsys" ]; then
            repo="$DOTSYS_REPOSITORY/builtins"

        else
            repo="$(dotfiles_dir)/$repo"
        fi

        if [ -d "$repo/$topic" ]; then
            if [ "$format" = "dir" ]; then
                echo "$repo/$topic"
            else
                echo "$topic"
            fi

        fi

    done < "$(state_file "dotsys")"
}