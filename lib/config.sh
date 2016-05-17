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
    local ACTIVE_REPO

    debug "-- load_config_vars: $action from: $repo"

    debug "   load_config_vars: loading default config"

    # load default cfg (prefix with ___)
    local yaml="$(parse_yaml "$(dotsys_dir)/dotsys.cfg" "___")"
    #debug "$yaml"
    eval "$yaml" #set default config vars

    debug "   load_config_vars: validate from"

    # validate from and set config_file
    if [ "$repo" ]; then
        validate_config_or_repo "$repo" "$action"
    # existing user (no from supplied)
    else
        ACTIVE_REPO="$(get_active_repo)"
        config_file="$(get_config_file_from_repo "$active_repo")"
        debug "existing user repo: $ACTIVE_REPO"
        debug "existing user cfg: $config_file"
    fi

    # Set ACTIVE_REPO & config_file for new user/repo
    if [ ! "$ACTIVE_REPO" ] ; then
        if is_new_user && [ "$action" != "uninstall" ]; then
            new_user_config "$repo"
        else
            prompt_config_or_repo "$action" "A repo must be specified!"
        fi
    fi

    # MANAGE REPO Make sure repo is installed updated
    # Skip on uninstall, unless "repo" is in limits.
    if [ "$action" != "uninstall" ] || in_limits "repo" -r; then
        # preconfirm when repo is in limits
        if in_limits "repo" -r; then confirmed="--confirmed"; fi

        if in_limits "repo" "dotsys"; then
            debug "   load_config_vars -> call manage_repo"
            manage_repo "$action" "$ACTIVE_REPO" "$force" "$confirmed"
        fi
        status=$?
    fi

    # make sure we get config file from a downloaded repo
    if ! [ "$config_file" ]; then
        config_file="$(get_config_file_from_repo "$ACTIVE_REPO")"
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


    # ABORT HERE ON UNINSTALL REPO
#    if [ "$action" = "uninstall" ] && in_limits "repo" -r; then
#        debug "   load_config_vars: repo in limits ABORT"
#        return
#    fi

    # Not required when limited to repo

    # must be set after config
    ACTIVE_REPO="$ACTIVE_REPO"
    ACTIVE_REPO_DIR="$(repo_dir)"
    debug "   load_config_vars: set ACTIVE_REPO=$ACTIVE_REPO"
    debug "   load_config_vars: set ACTIVE_REPO_DIR=$ACTIVE_REPO_DIR"

    # Set default cmd app manager as per config or default
    set_default_managers
    debug "   load_config_vars: set DEFAULT_APP_MANAGER=$DEFAULT_APP_MANAGER"
    debug "   load_config_vars: set DEFAULT_CMD_MANAGER=$DEFAULT_CMD_MANAGER"

    # Show config info when more then one topic
    if verbose_mode; then print_stats; fi
}

# sets config_file & config_file
# from user specific file or repo
validate_config_or_repo (){

    local input="$1"
    local action="$2"
    local prev_error=0

    local status=0

    # FILE: anything with . must be a file
    if [[ "$input" =~ ^[^/]*\.cfg$ ]]; then
        config_file="$input"
        ACTIVE_REPO="$(get_repo_from_config_file "$config_file")"

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
        ACTIVE_REPO="$input"
    fi

    # repo manager handles all other repo issues
    # nothing else to validate, pass silently

    return $status

}

CURRENT_LINES=
prompt_config_or_repo () {

    local action="${1:-install}"
    local error="$2"

    #find existing repos and offer choices
    #local config_files="$(find "$(dotfiles_dir)" -mindepth 1 -maxdepth 2 -type f -name 'dotsys.cfg -exec dirname {}')"
    #echo "found files: $config_files"

    local default
    if ! [ "$error" ]; then
        if [ "$ACTIVE_REPO" ]; then default=" [$ACTIVE_REPO]"
        elif [ "$config_file" ]; then default=" [$config_file]"
        fi
    fi


    local help="$(msg_help "$(printf "Use can type %bhelp%b for more info or %babort%b to exit" $blue $dark_gray $blue $dark_gray)")"
    local question="Enter a repo or config file to ${action}${default}"
    local prompt="$(printf "${help}\n${question}")"


    if [ "$error" ]; then
        clear_lines "$CURRENT_LINES"
        error="$(printf "%bERROR: ${error}, try again%b" $red $rc)"
        prompt="$(printf "${error}\n${prompt}")"
    fi

    CURRENT_LINES="$prompt"

    while true; do

        # Read from tty, needed because we read in outer loop.
        read -p "$prompt : " user_input < /dev/tty

        if [ "$user_input" = "abort" ]; then
           exit
        elif [ "$user_input" = "help" ]; then

            clear_lines "$CURRENT_LINES"

            local help="$(printf "%b
                   \rSETUP HELP:

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
                   \r  Provide a full path to a %bdotsys.cfg%b file and we'll take
                   \r  it form there.

                   \rEASY!%b" \ $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $blue $dark_gray $rc)"

            printf "\r$help \n\n"

        elif [ "$user_input" ]; then
            break

        elif [ "$default" ]; then
            user_input="$default"
            break
        else
            clear_lines "$CURRENT_LINES"
            error=
        fi
    done

    validate_config_or_repo "$user_input" "$action"
    return $?
}


# USER CONFIG

is_new_user () {
    # Empty user state file is new user
    ! [ -s "$(state_file "user")" ]
    return $?
}

new_user_config () {
    local repo="$1"

    print_logo "$repo"

    msg "$(printf "A multiform package manger with dotfile integration!")"
    printf "\n"
    msg "$(printf "Before getting started we have a few questions.")"
    printf "\n"

    prompt_config_or_repo "$action"

    user_config_logo

    user_config_stats

    user_config_stubs

    msg "\nCongratulations ${USER_NAME}, your preferences are set!\n"
    msg "Now were going to configure your repo.\n"
}

set_user_vars () {
    local repo="$1"
    USER_NAME="$(cap_first "$(whoami)")"
}

get_config_file_from_repo () {
  if ! [ "$1" ]; then return 1;fi
  echo "$(repo_dir "$1")/dotsys.cfg"
}

get_repo_from_config_file () {
    local file="$1"
    if [ -f "$file" ]; then
        local line="$(grep "repo:*" "$file")"
        echo "${line#*: }"
    fi
}

user_config_logo () {
    get_user_input "Would you like to see the dotsys logo when
            $spacer working on multiple topics (it's helpful)?"
    set_state_value "SHOW_LOGO" $? "user"
}

user_config_stats () {
    get_user_input "Would you like to see the dotsys stats when
            $spacer working on multiple topics (it's helpful)?"
    set_state_value "SHOW_STATS" $? "user"
}

user_config_stubs () {
    info "The stub file process allows topics to collect user specific
  $spacer information and sources topic related files from other topics
  $spacer such as *.shell, *.bash, *.zsh, *.vim, etc.. You should say yes!"

    get_user_input "Would you like use dotsys sub files?"
    local status=$?
    set_state_value "use_stub_files" $status "user"

    if ! [ $status -eq 0 ]; then return;fi
    warn "If your *.symlink files source files from topics by extension
  $spacer such as, *.shell, *.bash, *.zsh, etc.. you should remove those
  $spacer functions if you installed the associated dotsys stub file.

  $spacer IMPORTANT NOTE: Dotsys does not source *.sh files from topics!
  $spacer - shell extensions are sourced by all shells.
  $spacer - bash  extensions are sourced by bash only.
  $spacer - zsh  extensions are sourced by zsh only.
  $spacer Check your topic directories for new *.stub files
  $spacer to see which topics are stubbed and what they do."
}

print_logo (){
if ! get_state_value "show_logo" "user" || [ $SHOW_LOGO -eq 1 ] || ! verbose_mode; then
    return
fi

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
SHOW_LOGO=1
}

print_stats () {
    if ! get_state_value "show_stats" "user" || [ $SHOW_STATS -eq 1 ] || ! verbose_mode; then
        return
    fi

    info "$(printf "Active repo: %b${ACTIVE_REPO}%b" $green $rc)"
    info "$(printf "App package manager: %b%s%b" $green $DEFAULT_APP_MANAGER $rc)"
    info "$(printf "Cmd Package manager: %b%s%b" $green $DEFAULT_CMD_MANAGER $rc)"
    info "$(printf "There are %b${#topics[@]} topics to $action%b" $green $rc)"
    # make sure it's only seen once
    SHOW_STATS=1
}

# TOPIC CONFIG

# read yaml file
load_topic_config_vars () {
    local topic="$1"
    local loaded="_${topic}_config_loaded"
    local builtin_cfg="$(builtin_topic_dir "$topic")/dotsys.cfg"
    local topic_cfg="$(topic_dir "$topic")/dotsys.cfg"

    # exit if config is loaded or does not exist
    if [ "${!loaded}" ]; then return; fi
    # Load default topic config
    if [ -f "$builtin_cfg" ];then
        eval "$(parse_yaml "$builtin_cfg" "_${topic}_")"
    fi
    # overwrite default with repo topic config
    if [ -f "$topic_cfg" ];then
        eval "$(parse_yaml "$topic_cfg" "_${topic}_")"
    fi
    eval "${loaded}=true"
}


# PRIMARY METHOD FOR GETTING CONFIGS
get_topic_config_val () {
    # Returns the prevailing value for a given config
    local topic="$1"
    shift

    local splat="$(specific_platform)"
    local gplat="$(generic_platform)"
    local cfg_vars=()
    local val
    local var

    # configs are sourced from specific to general
    # repo configs supered topic configs
    # user configs supered default configs

    # user repo (topic platform & topic root)

    cfg_vars+=("_$topic $splat $@")
    cfg_vars+=("_$topic $gplat $@")
    cfg_vars+=("_$topic $@")

    # topic (platform & root)

    cfg_vars+=("$topic $splat $@")
    cfg_vars+=("$topic $gplat $@")
    cfg_vars+=("$topic $@")

    # user repo (root platform & root)

    cfg_vars+=("_$splat $@")
    cfg_vars+=("_$gplat $@")
    cfg_vars+=("_ $@")

    # default repo (root platform & root)

    cfg_vars+=("__$splat $@")
    cfg_vars+=("__$gplat $@")
    cfg_vars+=("__ $@")

    for var in "${cfg_vars[@]}";do
        val="$(get_config_val $var)"
        if [ "$val" ] && [ "$val" != "$topic" ];then
            echo "$val"
            return 0
        fi
    done
    return 1
}




