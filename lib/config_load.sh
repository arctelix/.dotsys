#!/bin/bash


# Configuration functions
# Author: arctelix


# NEVER USE ACTUAL VARS DIRECTLY; USE THIS METHOD OR GET_TOPIC_CONFIG_VAL!
get_config_val () {
  # TYPE                         ACTUAL VAR      CALL AS
  # topic config file (root)     _$topic         get_config_val "$topic"
  # user config file  (root)     __$topic        get_config_val "_$cfg"
  # user config file  (topic)    __$topic_$cfg   get_config_val "_$topic" "$cfg"
  # default config file (root)   ___$cfg         get_config_val "__$cfg"
  # default config file (topic)  ___$topic_$cfg  get_config_val "__$topic" "$cfg"

  # Dashes are removed from parts since dashes are not valid in variable names

  if [ $# -eq 0 ]; then return;fi

  local cfg=""
  local part=

  # Allow dashes as first param to prevent extra dash on blank param
  if [ "$1" = "_" ] || [ "$1" = "__" ]; then
       cfg="${1//-}"
       shift
  fi
  for part in $@; do
     if ! [ "part" ]; then continue;fi
     cfg+="_${part//-}"
  done
  cfg="$cfg[@]"
  local c
  for c in "${!cfg}"; do
    echo "$c"
  done

}

load_default_config_vars () {
    debug "   load_config_vars: loading default config"

    # load DEFAULT CFG (prefix with ___)
    local yaml="$(parse_yaml "$(dotsys_dir)/dotsys.cfg" "___")"
    debug "LOADED DEFAULT CFG:"
    # debug "$yaml"
    eval "$yaml" #set default config vars
}


load_config_vars (){
    # Defaults to state_reop config file or specify repo or path to config file

    local repo="$1"
    local action="$2"

    # set by validate_config_or_repo or new_user_config
    local config_file
    #sets global ACTIVE_REPO
    #sets global ACTIVE_REPO_DIR

    debug "-- load_config_vars: $action from: $repo"

    load_default_config_vars

    # validate from and set config_file
    if [ "$repo" ] && [ "$repo" != "none" ] ; then
        debug "   load_config_vars validate: $repo"
        validate_config_or_repo "$repo" "$action"
    # existing user (no from supplied)
    else
        ACTIVE_REPO="$(get_active_repo)"
        config_file="$(get_config_file_from_repo "$ACTIVE_REPO")"
        debug "   load_config_vars: existing user repo: $ACTIVE_REPO"
        debug "   load_config_vars: existing user cfg: $config_file"
    fi

    debug "   load_config_vars: ACTIVE_REPO = $ACTIVE_REPO"

    # Set ACTIVE_REPO & config_file for new user/repo
    if ! [ "$ACTIVE_REPO" ]; then
        if is_new_user && [ "$action" != "uninstall" ]; then
            new_user_config_repo
        else
            prompt_config_or_repo "$action" --error "A repo must be specified!"
        fi

    fi

    # MANAGE REPO Make sure repo is installed updated
    # Skip on uninstall, unless "repo" is in limits.
    if [ "$action" != "uninstall" ] || in_limits "repo" -r; then
        debug "MANAGE REPO limits=$limits topics=$topics"

        if in_limits "repo" "dotsys" && ! [ "$topics" ]; then
            debug "   load_config_vars -> call manage_repo"
            manage_repo "$action" "$ACTIVE_REPO" "$force"
        fi
    fi

    # make sure we get config file from a downloaded repo
    if ! [ "$config_file" ]; then
        config_file="$(get_config_file_from_repo "$ACTIVE_REPO")"
    fi

    debug "   load_config_vars: load config file"
    # load USER REPO CFG vars (prefix with __)
    if [ -f "$config_file" ]; then
        load_repo_config_vars "$config_file"
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

    debug "END LOAD CONFIG"
}

load_repo_config_vars () {
    local config_file="$1"
    local loaded="_repo_config_loaded"
    local yaml
    # exit if config is loaded or does not exist
    if [ "${!loaded}" ]; then return; fi

    # load USER REPO CFG vars (prefix with __)
    if [ -f "$config_file" ]; then
        yaml="$(parse_yaml "$config_file" "__")"
        debug "LOADED REPO CFG:"
        # debug "$yaml"
        eval "$yaml" #set config vars
        eval "${loaded}=true"
    fi
}



# sets config_file & config_file
# from user specific file or repo
validate_config_or_repo (){

    local input="$1"
    local action="$2"
    local prev_error=0

    local ret=0

    # Special repo key word to disregard user default
    if [ "$input" = "none" ]; then
        prompt_config_or_repo "$action" --default "$(state_primary_repo)"

    # FILE: anything with . must be a file
    elif [[ "$input" =~ ^[^/]*\.cfg$ ]]; then
        config_file="$input"
        ACTIVE_REPO="$(get_repo_from_config_file "$config_file")"

        # catch file does not exist
        if ! [ -f "$config_file" ]; then
            prompt_config_or_repo "$action" --error "Config file was not found at $config_file"
            return
        fi

        msg "Using config file : $config_file\n"

    # must be repo
    elif [ "$input" ]; then

        # catch repo incorrect format
        if ! [[ "$input" =~ ^[^/].*/.*$ ]]; then
            ((error_count+=1))
            prompt_config_or_repo "$action" --error "Repo must be in the format 'github_user/repo_name[:branch]'"
            return
        fi

        # get the repo config file
        config_file="$(get_config_file_from_repo "$input")"
        ACTIVE_REPO="$input"
    fi

    # repo manager handles all other repo issues
    # nothing else to validate, pass silently

    return $ret

}

CURRENT_LINES=
prompt_config_or_repo () {

    local action="${1:-install}"
    shift

    local usage="prompt_config_or_repo [<option>]"
    local usage_full="
        -e | --error        Display error message
        -d | --default      Display default
    "

    local error
    local default

    while [[ $# > 0 ]]; do
        case "$1" in
        -e | --error )          error="$2";shift ;;
        -d | --default )        default="$2";shift  ;;
        *)  invalid_option "$1" ;;
        esac
        shift
    done

    #find existing repos and offer choices
    #local config_files="$(find "$(dotfiles_dir)" -mindepth 1 -maxdepth 2 -type f -name 'dotsys.cfg -exec dirname {}')"
    #echo "found files: $config_files"
    debug "prompt_config_or_repo AR: ${ACTIVE_REPO}"
    debug "prompt_config_or_repo GAR:$(get_active_repo)"

    if ! [ "$error" ]; then
        if [ "$(get_active_repo)" ]; then default="${default:-$(get_active_repo)}"
        elif [ "$config_file" ]; then default="$config_file"
        fi
    fi

    local help="$(msg_help "$(printf "Type %bhelp%b for more details or %babort%b to exit" $c_code $c_help $c_code $c_help)")"
    local question="Enter a repo or config file to ${action}"
    local prompt="$(printf "${help}\n${question}")"


    if [ "$error" ]; then
        clear_lines "$CURRENT_LINES"
        error="$(printf "%bERROR: ${error}, try again%b" $red $rc)"
        prompt="$(printf "${error}\n${prompt}")"
    fi

    CURRENT_LINES="$prompt"

    while true; do

        # Read from tty, needed because we read in outer loop.
        if [ "$default" ]; then
        read -p "$prompt [$default] : " user_input < /dev/tty
        else
        read -p "$prompt : " user_input < /dev/tty
        fi

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

                   \rOPTION 2 (cofig file):

                   \r  Alternately, Provide a full path to a %bdotsys.cfg%b file and we'll take
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
        debug "** loading b topic cfg: $builtin_cfg"
        eval "$(parse_yaml "$builtin_cfg" "_${topic}_")"
    fi
    # overwrite default with repo topic config
    if [ "$builtin_cfg" != "$topic_cfg" ] && [ -f "$topic_cfg" ];then
        debug "** loading topic cgf  : $topic_cfg"
        eval "$(parse_yaml "$topic_cfg" "_${topic}_")"
    fi
    eval "${loaded}=true"
}


# PRIMARY METHOD FOR GETTING CONFIGS
# Returns the prevailing value for a given config
# default mode returns first found variable from topic to generic
# mode "+" : Combine all unique values from topic to generic
# mode "-" : Combine all unique values from generic to topic
get_topic_config_val () {
    # Dashes are removed from topic names
    # since dashes are not valid in variable names
    local topic="${1//-}"
    shift

    local splat="$(specific_platform)"
    local gplat="$(generic_platform)"
    local cfg_vars=()
    local val
    local vala
    local var
    local rv=1

    local mode

    if [ "$1" = "+" ]; then
        shift
        mode=add
    elif [ "$1" = "-" ]; then
        shift
        mode=rev
    fi

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


    if [ "$mode" = "rev" ];then
        reverse_array cfg_vars
    fi

    local values=()
    for var in "${cfg_vars[@]}";do

        while IFS=$'\n' read -r val;do

            if ! [ "$val" ];then continue;fi

            # Default returns first found variable value only
            if ! [ "$mode" ];then
                echo "$val"
                return 0

            # Add all unique values
            elif ! [[ "${values[@]}" =~ $val ]];then
                echo "$val"
                values+=("$val")
                rv=0

            fi
        done <<< "$(get_config_val $var)"
    done

    return $rv
}



