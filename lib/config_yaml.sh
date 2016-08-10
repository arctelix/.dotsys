#!/bin/bash

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
_cfg_yaml_last_node=""
CFG_MODES="user topic default full"
# Output topic config to yaml file
create_config_yaml() {

    local usage="create_config_yaml [<option>]"
    local usage_full="
        -c | --cfg      Specify config mode
                        user    : prints only user settings
                        topic   : prints topic $ user settings
                        default : prints all non blank keys (user, topic, default)
                        full    : prints all keys
    "

    local repo="$1"; shift
    local levels=()
    local parent=

    local cfg_mode="${3:-$cfg_mode}"

    while [[ $# > 0 ]]; do
        case "$1" in
        -c | --cfg )      cfg_mode="$2";shift ;;
        *)                levels+=("$1") ;;
        esac
        shift
    done

    local repo_d="$(repo_dir "$repo")"
    NODES=("$repo_d"/*)

    # FIRST CALL ONLY (non recursive)
    if ! [ "$_cfg_yaml_last_node" ];then

        debug "-- create_config_yaml r:$repo m:$cfg_mode levels:${levels[*]}"

        load_repo_config_vars "$(get_config_file_from_repo "$repo")"

        _cfg_yaml_last_node="${NODES[${#NODES[@]}-1]}"

        cfg_mode="${cfg_mode:-default}"
        if ! [[ "$CFG_MODES" =~ "$cfg_mode" ]];then
           error "$(printf "Not a valid cfg mode '${cfg_mode}'.
                    $spacer try: $CFG_MODES")"
           exit
        fi

        # init file and root config
        local yaml_file="${repo_d}/.dotsys-${cfg_mode}.cfg.dslog"

        # root level config
        echo "$cfg_mode date:$(date '+%d/%m/%Y %H:%M:%S')" > $yaml_file
        echo "$cfg_mode date:$(date '+%d/%m/%Y %H:%M:%S')"

        cfg_list_to_file
    fi

    local i
    for i in "${NODES[@]}";do
        local n="${i##*/}"
        local node="${n%.*}"
        local fnode="$(echo "$n" | tr . _ )"

        debug "START NEW NODE: $n"

        # node is topic
        if [ -d "$i" ];then
            load_topic_config_vars "$node"
            cfg_val_to_file ${levels[@]} "$node"
            cfg_list_to_file ${levels[@]} "$node"
            # go to next level
            debug "NEX LEVEL IN -> ${levels[*]} $node"
            create_config_yaml "$i" ${levels[*]} "$node" --cfg "$cfg_mode"

        # node is file
        elif [ -f "$i" ]; then
            # ignore files list
            if ! [[ "$node" =~ (install|uninstall|update|freeze|upgrade|dotsys|topic|manager) ]]; then
                cfg_val_to_file ${levels[*]} "$fnode"
                # Get settings from inside settings file
                if [ "$fnode" != "${fnode%_settings}" ];then
                    local settings="$(grep '^[^#].*()' "$i")"
                    local s
                    for s in "$settings"; do
                        s="${s% ()*}"
                        cfg_val_to_file ${levels[*]} "$fnode" "$s"
                    done
                fi
            fi
        fi

        # last node
        if [ "$i" = "$_cfg_yaml_last_node" ]; then
            success "Saved $cfg_mode config file for" "$(printf "%b${repo}" "$hc_topic")" "to
             $spacer -> $yaml_file"
            _cfg_yaml_last_node=""
        fi

    done
}

# each node including root should process this function
cfg_list_to_file () {

    local plat

    # All level general settings
    cfg_all_levels $@

    # Platform configs
    for plat in $PLATFORMS; do

        # make platform entry
        cfg_val_to_file $@ "$plat"

        # root level only
        if ! [ "$1"  ]; then
            cfg_val_to_file "$plat" "cmd_manager"
            cfg_val_to_file "$plat" "app_manager"
            cfg_all_levels "$plat"

        # all other levels
        else
            cfg_all_levels $@ "$plat"
        fi
    done
}

# std list of settings for all levels
cfg_all_levels () {
    # All level general settings
    cfg_val_to_file $@ "repo"
    cfg_val_to_file $@ "manager"
    cfg_val_to_file $@ "deps"
    cfg_val_to_file $@ "symlinks"
}

last_value_root=
# actually looks up value and directs to file
cfg_val_to_file (){

    local usage="cfg_to_file [<option>]"
    local usage_full="
        -r | --required        Key is required, even without value                     
    "

    local req
    local base=()
    local cfg_mode="$cfg_mode"
    
    while [[ $# > 0 ]]; do
        case "$1" in
        -r | --required )    req=" ";;
        *)  if [ "$1" ]; then base+=("$1"); fi;;
        esac
        shift
    done

    local len=$((${#base[@]} - 1))
    local level=$(printf '%*s' $((len * 2)))

    local sub=(${base[$len]})
    base=(${base[@]:0:$len})

    local val=
    local u_val=$(get_config_val "_" ${base[*]} "$sub")
    local t_val=$(get_config_val ${base[*]} "$sub")
    local d_val=$(get_config_val "__" ${base[*]} "$sub")



    # user config val
    if [ "$u_val" ]; then
        val="$u_val"
    # topic config val
    elif [ "$t_val" ] && [ "$cfg_mode" != "user" ]; then
        val="$t_val"
    # default val
    elif [ "$d_val" ] && ! [[ "$cfg_mode" =~ (user|topic) ]]; then
        val="$d_val"
    fi

    debug "$level${base[*]}|${sub[*]}=$val"
    if [[ "${val:-$req}" && "$base" ]]; then
        if [ "$req" ] || [[ "$last_value_root" != "${base[0]}" ]];then
            if [ "${val}" ]; then
                last_value_root="${base[0]}"
            fi
            local n_len=$((${#base[@]} - 1))
            local n_sub=(${base[$n_len]})
            local n_base
            if [ $n_len -gt 0 ];then
                n_base=(${base[@]:0:$n_len})
            fi
            debug " -> get parent |${n_base[*]}|$n_sub|"
            cfg_val_to_file ${n_base[*]} ${n_sub[*]} -r
        fi
    fi

    # Mode detection
    if ! [ "${val:-$req}" ] && ! [ "$cfg_mode" = "full" ] ; then return; fi

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