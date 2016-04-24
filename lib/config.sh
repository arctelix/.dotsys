#!/bin/sh

load_config_vars (){
    # Defaults to state_reop config file or specify repo or path to config file

    local from="$1"
    local action="${2:-$action}"
    local config_file=

    debug "load_config_vars $action from: $from"
    # load default cfg (prefix with ___)
    local yaml="$(parse_yaml "$(dotsys_dir)/.dotsys.cfg" "___")"
    #debug "$yaml"
    eval "$yaml" #set default config vars

    local active_repo="$(get_active_repo)"
    local active_repo_dir="$(repo_dir "$active_repo")"

    # get active repo cfg file if no from supplied
    if ! [ "$from" ] && [ -d "$active_repo_dir" ]; then
        confirm_make_primary_repo "$active_repo"
        config_file="$(get_repo_config_file "$active_repo")"

    # get user specified cfg file or repo cfg file
    elif [ "$from" ]; then
       validate_config_or_repo "$from" "$action"

    # assume we got a new user
    else
       new_user_config
    fi

    # load the user config file vars (prefix with __)
    if [ -f "$config_file" ]; then
        yaml="$(parse_yaml "$config_file" "__")"
        #debug "config vars loaded:"
        #debug "$yaml"
        eval "$yaml" #set config vars
    # warn no config
    else
        warn "No config file was found in $config_file !"
    fi

    # must be set after config
    ACTIVE_REPO="$(get_active_repo)"
    ACTIVE_REPO_DIR="$(repo_dir)"
    info "$(printf "Active repo: %b${ACTIVE_REPO}%b" $green $rc)"

    # Set default cmd app manager as per config or default
    set_default_managers
}

# read yaml file
load_topic_config_vars () {
    local topic="$1"
    local loaded="_${topic}_config_loaded"
    local file="$(topic_dir ${topic})/.dotsys.cfg"
    # exit if config is loaded or does not exist
    if [ "${!loaded}" ] || ! [ -f "$file" ];then return; fi
    # Load topic config ( is eval the only way? )
    eval "$(parse_yaml $file "_${topic}_")"
    eval "${loaded}=true"
}


# PRIMARY METHOD FOR GETTING CONFIGS
get_topic_config_val () {
  # Returns the prevailing value for a given config
  local topic="$1"
  shift

  # can't call load_topic_config_vars here because it's called in sub shell!! :(

  local user_topic_plat_cfg="$(get_config_val "_$topic" "$PLATFORM" "$@")"
  local user_topic_cfg="$(get_config_val "_$topic" "$@")"
  local topic_plat_cfg="$(get_config_val "$topic" "$PLATFORM" "$@")"
  local topic_cfg="$(get_config_val "$topic" "$@")"
  local user_gen_plat_config="$(get_config_val "_$PLATFORM" "$@")"
  local user_gen_config="$(get_config_val "_" "$@")"
  local def_plat_config="$(get_config_val "__$PLATFORM" "$@")"
  local def_config="$(get_config_val "__" "$@")"
  local val=


  # use user topic if defined config
  if [ "$user_topic_plat_cfg" ];then
    val="$user_topic_plat_cfg"
  # use user topic platform config
  elif [ "$user_topic_cfg" ];then
    val="$user_topic_cfg"

  # use topic platform config
  elif [ "$topic_plat_cfg" ];then
    val="$topic_plat_cfg"
  # use topic config
  elif [ "$topic_cfg" ];then
    val="$topic_cfg"

  # use root user platform
  elif [ "$user_gen_plat_config" ];then
    val="$user_gen_plat_config"
  # use root user
  elif [ "$user_gen_config" ];then
    val="$user_gen_config"

  # use default platform
  elif [ "$def_plat_config" ];then
    val="$def_plat_config"
  # use default
  elif [ "$def_config" ];then
    val="$def_config"
  fi

  if [ "$val" = "$topic" ];then
    val=""
  fi

  echo "${val[@]}"
}

# NEVER USE ACTUAL VARS DIRECTLY; USE THIS METHOD!
get_config_val () {
  # TYPE                         ACTUAL VAR      CALL AS
  # topic config file (root)     _$topic         get_config_val "$topic"
  # user config file  (root)     __$topic        get_config_val "_$cfg"
  # user config file  (topic)    __$topic_$cfg   get_config_val "_$topic" "$cfg"
  # default config file (root)   ___$cfg         get_config_val "__$cfg"
  # default config file (topic)  ___$topic_$cfg  get_config_val "__$topic" "$cfg"

  if [ $# -eq 0 ]; then return;fi

  local cfg=""
  local part=

  # Allow dashes as first param to prevent extra dash on blank param
  if [ "$1" = "_" ] || [ "$1" = "__" ]; then
       cfg="$1"
       shift
  fi
  for part in $@; do
     if ! [ "part" ]; then continue;fi
     cfg+="_$part"
  done
  cfg="$cfg[@]"
  echo "${!cfg}"
}

get_repo_config_file () {
  echo "$(dotfiles_dir)/${1}/.dotsys.cfg"
}

get_topic_manager () {

    local topic="$1"

    local manager=$(get_topic_config_val "$topic" "manager")

    if ! [ "$manager" ]; then
      return
    fi

    # convert generic names to defaults
    if [ "$manager" = "cmd" ]; then
      manager="$DEFAULT_CMD_MANAGER"
    elif [ "$manager" = "app" ]; then
      manager="$DEFAULT_APP_MANAGER"
    fi
    echo "$manager"
}


freeze() {
    local dir=$1
    local topics=($(find $dir -maxdepth 1 -type d -not -name '\.*'))
    for t in ${topics[@]}
    do
        # remove leading ./
        TS=${t:1}":yes"
        echo $TS >> dotsys-freeze.txt
        echo $TS
    done
}


print_debugo (){

if [ "$(get_state_value "show_debugo")" = "1" ]; then return;fi

set_user_vars "$(get_active_repo)"
if [ "$USER_NAME" ]; then
    local message="Welcome To Dotsys $USER_NAME"
else
    local message="WELCOME  TO  YOUR  DOTSYS"
fi

printf "%b
  (          )
  )\ )    ( /(   (
 (()/( (  )\()|  )\ ) (
  ((_)))\(_))/)\(()/( )\\
  _| |((_) |_((_))(_)|(_)
/ _\` / _ \  _(_-< || (_-<
\__,_\___/\__/__/\_, /__/
                 |__/

%s%b\n\n" $dark_red "$message" $rc
}


new_user_config () {

    msg "$(printf "We need configure your primary repo")"
    msg_help "$(printf "Use can type %bhelp%b for more info" $blue $dark_gray)"
    printf "\n"

    prompt_config_or_repo "install"

    copy_topics_to_repo "$PRIMARY_REPO"

    user_toggle_debugo

    msg "\nCongratulations, your repo is ready to go ${USER_NAME}!\n"
}

user_toggle_debugo () {
    get_user_input "Would you like to disable the dotsys debugo" --false yes --true no
    set_state_value "show_debugo" $?
}


set_user_vars () {
    local repo="$1"
    PRIMARY_REPO="$repo"
    USER_NAME="$(cap_first ${repo%/*})"
    REPO_NAME="${repo#*/}"
}


prompt_config_or_repo () {

    local action="${1:-install}"
    local error="$2"


    # TODO: find existing repos and offer choices
    #local config_files="$(find "$(dotfiles_dir)" -mindepth 1 -maxdepth 2 -type f -name '.dotsys.cfg -exec dirname {}')"
    #echo "found files: $config_files"

    local default=
    if [ "$active_repo" ]; then default=" [$active_repo]"; fi
    local q_repo="Enter a repo or config file to ${action}${default} : "


    if [ "$error" ]; then
        error "${error}, try again:"
    else
        printf "$q_repo"
    fi

    while true; do
        # Read from tty, needed because we read in outer loop.
        read user_input < /dev/tty

        local repo="$(dotfiles_dir)$user_input"

        if [ "$user_input" = "abort" ]; then
           exit
        elif [ "$user_input" = "help" ]; then

            printf $clear_line_above
            local h_repo=
            h_repo+="%bOPTION 1 (repo): A repo is simply a github repository containing your topics. "
            h_repo+="Specify a remote github repository as %bgithub_user/repo_name%b.\n\n"

            h_repo+="If the remote repo exists we'll download it. Otherwise, it will be created "
            h_repo+="locally in your dotfiles directory. Then move any existing topics you may have "
            h_repo+="to this sub directory %bdotfiles/github_user/repo_name%b.\n\n"

            h_repo+="OPTION 2 (cofig file): A %bconfig file%b is a way to specify repos & topic configs. "
            h_repo+="Provide a full path to a %b.dotsys.cfg%b file and we'll take it form there.\n\n"

            h_repo+="EASY!%b\n\n"

            printf "$h_repo" $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $rc

            printf "$q_repo"
        elif [ "$user_input" ]; then
            break

        else
            user_input="$active_repo"
            break
        fi
    done

    validate_config_or_repo "$user_input" "$action"
    return $?
}


validate_config_or_repo (){

    # sets config_file from user specific file or repo
    local from_src="$1"
    local action="$2"

    local status=0

    # FILE: anything with . must be a file
    if [[ "$from_src" =~ ^.*\..*$ ]]; then
        config_file="$from_src"

        # catch file does not exist
        if ! [ -f "$config_file" ]; then
            prompt_config_or_repo "$action" "Config file was not found at $config_file"
            printf $clear_line_above
            return
        fi

    # must be repo
    elif [ "$from_src" ]; then

        # catch repo incorrect format
        if ! [[ "$from_src" =~ ^[^/].*/.*$ ]]; then
            prompt_config_or_repo "$action" "Repo must be in the format 'github_user/repo_name'"
            printf $clear_line_above
            return
        fi

        # make sure repo is installed updated
        if [ "$action" != "uninstall" ]; then
            manage_repo "$action" "$from_src"
            status=$?
        fi

        # get the repo config file
        config_file="$(get_repo_config_file "$from_src")"
    fi
    return $status
    # nothing to validate, pass silently
}


