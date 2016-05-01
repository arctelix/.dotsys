#!/bin/sh

# NEVER USE ACTUAL VARS DIRECTLY; USE THIS METHOD OR GET_TOPIC_CONFIG_VAL!
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

load_config_vars (){
    # Defaults to state_reop config file or specify repo or path to config file

    local repo="$1"
    local action="$2"

    # set by validate_config_or_repo or new_user_config
    local config_file
    local active_repo

    debug "-- load_config_vars: $action from: $repo"

    debug "   load_config_vars: loading default config"

    # load default cfg (prefix with ___)
    local yaml="$(parse_yaml "$(dotsys_dir)/.dotsys.cfg" "___")"
    #debug "$yaml"
    eval "$yaml" #set default config vars

    debug "   load_config_vars: validate from"

    # validate from and set config_file
    if [ "$repo" ]; then
        validate_config_or_repo "$repo" "$action"
    # existing user (no from supplied)
    else
        active_repo="$(get_active_repo)"
        config_file="$(get_config_file_from_repo "$active_repo")"
    fi

    if [ ! "$active_repo" ] ; then
        if is_new_user && [ "$action" != "uninstall" ]; then
            new_user_config "$repo"
        else
            error "A repo must be specified!"
            exit
        fi
    # Show logo when more then one topic
    elif [ ${#topics[@]} -gt 1 ]; then
        print_logo "$active_repo"
    fi

    # MANAGE REPO Make sure repo is installed updated
    # Skip on uninstall, unless "repo" is in limits.
    if [ "$action" != "uninstall" ] || in_limits "repo" -r; then
        debug "   load_config_vars: call manage_repo"
        if in_limits "repo" -r; then confirmed="--confirmed"; fi
        manage_repo "$action" "$active_repo" "$force" "$confirmed"
        status=$?
    fi

    # ABORT HERE ON UNINSTALL REPO
    if [ "$action" = "uninstall" ] && in_limits "repo" -r; then
        debug "   load_config_vars: repo in limits ABORT"
        return
    fi

    debug "   load_config_vars: load config file"
    # load the user config file vars (prefix with __)
    if [ -f "$config_file" ]; then
        yaml="$(parse_yaml "$config_file" "__")"
        #debug "load_config_vars loaded:"
        #debug "$yaml"
        eval "$yaml" #set config vars

    # warn no config
    else
        warn "No config file was found"
    fi

    # Not required when limited to repo
    debug "   load_config_vars: set ACTIVE_REPO vars"
    # must be set after config
    ACTIVE_REPO="$(get_active_repo)"
    ACTIVE_REPO_DIR="$(repo_dir)"

    # Set default cmd app manager as per config or default
    debug "   load_config_vars: set DEFAULT_MANGER vars"
    set_default_managers

    # Show config info when more then one topic
    if [ ${#topics[@]} -gt 1 ]; then print_stats; fi
}

# sets config_file & config_file
# from user specific file or repo
validate_config_or_repo (){

    local input="$1"
    local action="$2"
    local prev_error=0

    local status=0

    # FILE: anything with . must be a file
    if [[ "$input" =~ ^.*\..*$ ]]; then
        config_file="$input"
        active_repo="$(get_repo_from_config_file "$config_file")"

        # catch file does not exist
        if ! [ -f "$config_file" ]; then
            prompt_config_or_repo "$action" "Config file was not found at $config_file"
            #clear_lines "\n"
            return
        fi

        msg "Using config file : $config_file\n"

    # must be repo
    elif [ "$input" ]; then

        # catch repo incorrect format
        if ! [[ "$input" =~ ^[^/].*/.*$ ]]; then
            ((error_count+=1))
            prompt_config_or_repo "$action" "Repo must be in the format 'github_user/repo_name[:branch]'"
            #clear_lines "\n"
            return
        fi
        # get the repo config file
        config_file="$(get_config_file_from_repo "$input")"
        active_repo="$input"
    fi

    # repo manager handles all other repo issues
    # nothing else to validate, pass silently

    return $status

}

prompt_config_or_repo () {

    local action="${1:-install}"
    local error="$2"


    # TODO: find existing repos and offer choices
    #local config_files="$(find "$(dotfiles_dir)" -mindepth 1 -maxdepth 2 -type f -name '.dotsys.cfg -exec dirname {}')"
    #echo "found files: $config_files"

    local default=
    if [ "$active_repo" ]; then default=" [$active_repo]"
    elif [ "$config_file" ]; then default=" [$config_file]"
    fi

    local q_repo="Enter a repo or config file to ${action}${default}"
    if ! [ "$active_repo" ]; then
          q_repo+="$(printf "\n%brepo example: github_user/repo_name%b" $dark_gray $rc)"
    fi

    if [ "$error" ]; then
        clear_lines "$q_repo"
        msg "$(printf "%bERROR: ${error}, try again%b" $red $rc)"
        printf "$q_repo : "
    else
        printf "$q_repo : "
    fi

    while true; do
        # Read from tty, needed because we read in outer loop.
        read user_input < /dev/tty

        local repo="$(dotfiles_dir)$user_input"

        if [ "$user_input" = "abort" ]; then
           exit
        elif [ "$user_input" = "help" ]; then

            clear_lines "$q_repo"
            local h_repo="$(printf "%bSETUP HELP:%b

                   \rOPTION 1 (repo):

                   \r  A repo is simply a github repository containing
                   \r  your topics. Specify a remote github repository
                   \r  as %bgithub_user/repo_name%b.

                   \r  If the remote repo exists we'll download it. Otherwise,
                   \r  we'll create it locally in your dotfiles directory and
                   \r  optionally upload it to github.

                   \r  Then move any existing topics you have to the new folder
                   \r  %b~/.dotfiles/github_user/repo_name%b.

                   \rOPTION 2 (cofig file):

                   \r  A %bconfig file%b is a way to specify repos & topic configs.
                   \r  Provide a full path to a %b.dotsys.cfg%b file and we'll take
                   \r  it form there.

                   \rEASY!%b" \ $yellow $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $rc)"

            printf "\r$h_repo \n\n"

            printf "$q_repo : "
        elif [ "$user_input" ]; then
            break

        elif [ "$active_repo" ]; then
            user_input="$active_repo"
            break
        else
            clear_lines "$q_repo"
            printf "$q_repo : "
        fi
    done

    validate_config_or_repo "$user_input" "$action"
    return $?
}


# USER CONFIG

is_new_user () {
    ! [ "$(state_primary_repo)" ]

    return $?
}

new_user_config () {
    local repo="$1"

    print_logo "$repo"

    msg "$(printf "A multiform package manger with dotfile integration!")"
    printf "\n"
    msg "$(printf "Before getting started we have a few questions.")"
    msg_help "$(printf "Use can type %bhelp%b for more info" $blue $dark_gray)"
    printf "\n"

    prompt_config_or_repo "$action"

    if [ "$repo" ]; then
        set_user_vars "$active_repo"
    fi

    user_toggle_logo
    user_toggle_stats

    msg "\nCongratulations ${USER_NAME}, your preferences are set!\n"
    msg "Now were going to configure your repo.\n"
}

set_user_vars () {
    local repo="$1"
    PRIMARY_REPO="$repo"
    USER_NAME="$(cap_first "$(whoami)")" #"$cap_first ${repo%/*})"
    REPO_NAME="${repo#*/}"
}

get_config_file_from_repo () {
  echo "$(repo_dir "$1")/.dotsys.cfg"
}

get_repo_from_config_file () {
    local file="$1"
    if [ -f "$file" ]; then
        local line="$(grep "repo:*" "$file")"
        echo "${line#*: }"
    fi
}

freeze() {
    local dir=$1
    local topics=($(find $dir -maxdepth 1 -type d -not -name '\.*'))
    local t
    for t in ${topics[@]}
    do
        # remove leading ./
        TS=${t:1}":yes"
        echo $TS >> dotsys-freeze.txt
        echo $TS
    done
}

user_toggle_logo () {
    get_user_input "Would you like to see the dotsys logo when
            $spacer working on multiple topics (it's helpful)?"
    set_state_value "show_logo" $?
}

user_toggle_stats () {
    get_user_input "Would you like to see the dotsys stats when
            $spacer working on multiple topics (it's helpful)?"
    set_state_value "show_stats" $?
}

print_logo (){

if [ "$(get_state_value "show_logo")" = "1" ]; then return;fi
if [ $show_logo -eq 1 ]; then return;fi

local repo="${1:-$(get_active_repo)}"
set_user_vars "${1:-$(get_active_repo)}"
local message=
if [ "$USER_NAME" ]; then
    message="Welcome To Dotsys $USER_NAME"
else
    message="WELCOME  TO  YOUR  DOTSYS"
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

$message%b\n\n" $dark_red $rc
# make sure it's only seen once
show_logo=1
}

print_stats () {
    if [ "$(get_state_value "show_stats")" = "1" ]; then return;fi
    if [ $show_stats -eq 1 ]; then return;fi

    info "$(printf "Active repo: %b${ACTIVE_REPO}%b" $green $rc)"
    info "$(printf "App package manager: %b%s%b" $green $DEFAULT_APP_MANAGER $rc)"
    info "$(printf "Cmd Package manager: %b%s%b" $green $DEFAULT_CMD_MANAGER $rc)"
    info "$(printf "There are %b${#topics[@]} topics to $action%b" $green $rc)"
    # make sure it's only seen once
    show_stats=1
}
# TOPIC CONFIG

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



