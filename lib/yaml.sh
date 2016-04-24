#!/bin/sh

# Utils for reading and writing yaml
# Author: arctelix


# parse_yaml from: https://gist.github.com/epiloque/8cf512c6d64641bde388
parse_yaml() {
    local prefix=$2
    local s
    local w
    local fs
    s='[[:space:]]*'
    w='[a-zA-Z0-9_]*'
    fs="$(echo @|tr @ '\034')"
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s[:-]$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$1" |
    awk -F"$fs" '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=(\"%s\")\n", "'"$prefix"'",vn, $2, $3);
        }
    }' | sed 's/_=/+=/g'
}


# CREATE CONFIG YAML FILE
_last_node=""
FREEZE_MODES="user topic default full"
# Output topic config to yaml file
create_config_yaml() {
    local repo="$1"
    local level="$2"
    local freeze_mode=
    # freeze_mode=$3 (see below)
    # "user"    : prints only user settings
    # "topic"   : prints topic $ user settings
    # "default" : prints all non blank keys (user, topic, default)
    # "full"    : prints all keys

    local repo_d="$(repo_dir "$repo")"


    NODES=("$repo_d"/*)

    # FIRST CALL ONLY (non recursive)
    if ! [ "$_last_node" ];then
        # main takes care of loading config now
        #load_config_vars "$repo" "freeze"

        _last_node="${NODES[${#NODES[@]}-1]}"

        freeze_mode="${3:-default}"
        if ! [[ "$FREEZE_MODES" =~ "$freeze_mode" ]];then
           error "$(printf "Not a valid freeze mode '${mode}'.
           $spacer try: user, topic, default, full")"
           exit
        fi

        # init file and root config
        local yaml_file="${repo_d}/.dotsys-${freeze_mode}.cfg"

        task "$(printf "Saving a %b$freeze_mode config%b file to %b$yaml_file%b" $green $rc $green $rc)"

        # root level config
        echo "date: $(date '+%d/%m/%Y %H:%M:%S')" > $yaml_file
        echo "date: $(date '+%d/%m/%Y %H:%M:%S')"

        cfg_list_to_file "" ""

    fi

    local i
    for i in ${NODES[@]};do
        local n="${i##*/}"
        local node="${n%.*}"
        local fnode="$(echo "$n" | tr . _ )"

        # topic
        if [ -d "$i" ];then
            load_topic_config_vars "$node"
            cfg_val_to_file "$level" "$node"
            cfg_list_to_file "$level" "$node"

            # go to next level
            level+="  "
            create_config_yaml "$i" "$level"
            level="${level%  }"

        # file
        elif [ -f "$i" ]; then
            # ignore files list
            if ! [[ "$node" =~ (install|uninstall|update|freeze|upgrade|dotsys) ]]; then
                cfg_val_to_file "$level" "$fnode"
            fi
        fi

        # last node
        if [ "$i" = "$_last_node" ]; then
            success "$(printf "Freeze $freeze_mode config for %b${repo}%b\n$spacer -> %b$yaml_file%b" $green $rc $green $rc)"
            _last_node=""
        fi

    done
}

# each node including root should process this function
cfg_list_to_file () {
    local level="$1"
    local base="$2"
    local plat=
    local req=

    # All level general settings
    cfg_all_levels "$level" "$base"

    # Platform configs
    for plat in $PLATFORMS; do
        if ! [ "$base" ]; then req=" ";fi
        # make platform entry
        cfg_val_to_file "$level" "$base" "$plat" "$req"

        # root level only
        if ! [ "$base" ]; then
            cfg_val_to_file "$level" "$plat" "cmd_manager" "$req"
            cfg_val_to_file "$level" "$plat" "app_manager" "$req"
            cfg_all_levels "$level" "$plat"

        # all other levels
        else
            cfg_all_levels "$level  " "${base}_${plat}"
        fi
    done
}

# std list of settings for all levels
cfg_all_levels () {
    # All level general settings
    cfg_val_to_file "$1" "$2" "repo"
    cfg_val_to_file "$1" "$2" "manager"
    cfg_val_to_file "$1" "$2" "deps"
    cfg_val_to_file "$1" "$2" "symlinks"
}

# actually looks up value and directs to file
cfg_val_to_file (){
    local level="$1"
    local base="$2"
    local sub="$3"
    local req="$4"

    local val=
    local u_val=$(get_config_val "_$base" "$sub")
    local t_val=$(get_config_val "$base" "$sub")
    local d_val=$(get_config_val "__$base" "$sub")

    # user config val
    if [ "$u_val" ]; then
        val="$u_val"
    # topic config val
    elif [ "$t_val" ] && [ "$freeze_mode" != "user" ]; then
        val="$t_val"
    # default val
    elif [ "$d_val" ] && ! [[ "$freeze_mode" =~ (user|topic) ]]; then
        val="$d_val"
    fi

    # increase level for sub
    if [ "$base" ] && [ "$sub" ]; then level+="  ";fi

    # Mode detection
    if ! [ "${val:-$req}" ] && ! [ "$freeze_mode" = "full" ] ; then return; fi

    # detect list outputs
    if [[ "$sub" =~ (symlinks|deps) ]]; then
        list_to_file "${level}" "${sub:-$base}" "${val:-$req}"
    else
        kv_to_file "${level}${sub:-$base}" "${val:-$req}"
    fi
}

kv_to_file () {
  echo "${1}: ${2}" >> $yaml_file
  echo "${1}: ${2}"
}

list_to_file () {
  local indent="$1"
  echo "${indent}${2}:" >> $yaml_file
  echo "${indent}${2}:"
  local links=("$3")
  local link
  for link in ${links[@]}; do
    echo "${indent}  - ${link}" >> $yaml_file
    echo "${indent}  - ${link}"
  done
}