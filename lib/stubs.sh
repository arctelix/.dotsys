#!/bin/sh


# Checks user's system for existing configs and move to repo
# Make sure this only happens for new user install process
# or those configs will not get loaded
add_existing_dotfiles () {
    local repo="${repo:-$ACTIVE_REPO}"
    local topic
    local topic_stubs

    confirm_task "add" "any existing original dotfiles from your system to" "dotsys" \
         "(we'll confirm each file before moving it)"
    if ! [ $? -eq 0 ]; then return;fi

    # iterate builtin topics
    for topic in $(get_dir_list "$(dotsys_dir)/builtins"); do

        # iterate topic sub files
        local topic_dir="$(repo_dir "$repo")/$topic"
        local stub_files="$(get_topic_stub_sources "$topic")"
        local stub_dst
        local stub_target
        local stub_src
        debug "  add_existing_dotfiles topic = $topic"
        debug "  add_existing_dotfiles topic_dir = $topic_dir"
        debug "  add_existing_dotfiles stub_files = $stub_files"
        while IFS=$'\n' read -r stub_src; do
            debug "src = $stub_src"
            stub_dst="$(get_symlink_dst "$stub_src")"
            stub_target="$(get_topic_stub_target "$topic" "$stub_src" "user")"
            #user_stub_file="$(dotsys_user_stub_file "$topic" "$stub_src")"

            # Check for existing original file only (symlinks will be taken care of during stub process)
            if ! [ -L "$stub_dst" ] && [ -f "$stub_dst" ]; then
                if [ -f "$stub_target" ]; then
                    get_user_input "$(printf "You have two versions of %b$(basename "$stub_dst")%b:
                            $spacer current version: %b$stub_dst%b
                            $spacer dotsys version: %b$stub_target%b
                            $spacer Which version would you like to use with dotsys
                            $spacer (Don't stress, we'll backup the other one)?" $hc_topic $rc $hc_topic $rc $hc_topic $rc)" \
                            --true "current" --false "dotsys"

                    # keep system version: backup dotsys version before move
                    if [ $? -eq 0 ]; then
                        cp "$stub_target" "${stub_target}.dsbak"
                    # keep dotsys version: delete and backup system version
                    # symlink/stub process will take care of rest
                    else
                        mv "$stub_dst" "${stub_dst}.dsbak"
                        continue
                    fi

                else
                    confirm_task "move" "existing config file for" "$topic" \
                       "$(printf "%bfrom:%b $stub_dst" $hc_topic $rc )" \
                       "$(printf "%bto:%b $stub_target" $hc_topic $rc )"
                fi

                if ! [ $? -eq 0 ]; then continue;fi

                #create_user_stub "$topic" "$stub_src"

                # backup and move system version to dotsys
                cp "$stub_dst" "${stub_dst}.dsbak"
                mkdir -p "$(dirname "$stub_target")"
                mv "$stub_dst" "$stub_target"
                symlink "$stub_target" "$stub_dst"

            fi
        done <<< "$stub_files"
    done

}

# Collects all required user data at start of process
# Sources topic files
# Creates stub file in .dotsys/user/stub directory
# Stubs do not get symlinked untill topic is installed.
# However, since stubs are symlinked to user directory
# changes are instant and do not need to be relinked!
manage_stubs () {
    local usage="manage_stubs [<option>]"
    local usage_full="
        -f | --force        Force stub updates
        -d | --data         Collect user data only
        -t | --task         Show task messages
    "

    local action="$1"
    local topics=("$2")
    shift; shift

    #local builtins=$(get_dir_list "$(dotsys_dir)/builtins")
    local force
    local data_mode
    local task

    while [[ $# > 0 ]]; do
        case "$1" in
        -f | --force )        force="$1" ;;
        -t | --task )         task="task" ;;
        -d | --data_update )  data="$1"; data_mode="update" ;;
        -d | --data_collect ) data="$1"; data_mode="collect" ;;
        *)  invalid_option "$1";;
        esac
        shift
    done

    if [ "$action" = "uninstall" ] || [ "$action" = "freeze" ]; then return;fi

    # check if user accepted subs and at least one topic
    if ! get_state_value "user" "use_stub_files" || ! [ "${topics[0]}" ]; then
        return
    fi

    debug "-- manage_stubs: $action $mode $force"
    debug "   topics: ${topics[@]}"

    if [ "$data_mode" ]; then
        task "${data_mode}ing user data"
    elif [ "$task" ];then
        task "${action}ing stub files"
    fi

    for topic in ${topics[@]}; do
        # Abort no user topic and not a required stub file topic
        if ! [ -d "$(topic_dir "$topic" "user")" ] && ! is_required_stub; then
            continue
        fi
        manage_topic_stubs "$action" "$topic" "$data" "$task" "$force"
    done

}

# Manage all stubs for a topic
manage_topic_stubs () {
    local usage="manage_topic_stubs [<option>]"
    local usage_full="
        -f | --force        Force stub updates
        -d | --data         Collect user data only
        -t | --task         Show task messages
    "
    local action="$1"
    local topic="$2"

    shift; shift

    local force
    local data_mode
    local task
    local stub_file

    while [[ $# > 0 ]]; do
        case "$1" in
        -f | --force )        force="$1" ;;
        -t | --task )         task="task" ;;
        -d | --data_update )  data_mode="update" ;;
        -d | --data_collect ) data_mode="collect" ;;
        *)  invalid_option "$1";;
        esac
        shift
    done

    # check if user accepted subs
    if ! get_state_value "user" "use_stub_files"; then return; fi

    # Check for topic stub files
    local stub_files="$(get_topic_stub_sources "$topic")"
    if [ "$stub_files" ];then
        debug "-- manage_topic_stubs: $action $topic $data_mode $force"

        if [ "$data_mode" ]; then
            task "${data_mode}ing $topic data"
        elif [ "$task" ];then
            task "${action}ing $topic stub files"
        fi

        while IFS=$'\n' read -r stub_file; do
            debug "   found stub file for $topic -> $stub_file"

            if [ "$data_mode" = "collect" ]; then
                collect_user_data "$action" "$topic" "$stub_file" "" "$data_mode" "$force"
            elif [ "$action" = freeze ];then
                collect_user_data "$action" "$topic" "$stub_file" "" "$data_mode" "$force"
                collect_topic_sources "$action" "$topic" "$(basename "${stub_file%.*}")"
            else
                # Create/Update stub file with target, user data, and source files
                manage_user_stub "$action" "$topic" "$stub_file" "$data_mode" "$force"
            fi
        done <<< "$stub_files"
    fi

    # Check topic for other topic source files
    if ! [ "$data_mode" ]; then
        manage_topic_source_files "$action" "$topic"
    fi
}


# creates custom stub file in user/repo/topic
manage_user_stub () {

    # stub file variables are defined as {TOPIC_VARIABLE_NAME}
    # ex: {GIT_USER_EMAIL} checks for git_user_email ins state defaults to global user_email
    # ex: {USER_EMAIL} uses global user_email (does not check for topic specif value)

    local action="$1"
    local topic="$2"
    local stub_src="$3"
    local data_mode="$4"
    local force="$5"

    local stub_name="$(basename "${stub_src%.*}")"
    local file_action="update"

    # Convert stub_name to stub_src if required
    # This allows: create_user_stub "git" "gitconfig"
    if [ "$stub_src" = "$stub_name" ] ; then
        stub_src="$(get_user_or_builtin_file "$topic" "${stub_name}.stub")"
    fi

    # abort if there is no stub for topic
    if ! [ -f "$stub_src" ]; then
        error "$topic does not have a stub file at:\n$stub_src"
        return
    fi
    # exiting file.dsbak or user repo file.symlink or blank
    local stub_tar="$(get_topic_stub_target "$topic" "$stub_src")"
    local stub_dst="$(get_user_stub_file "$topic" "$stub_src")"
    local target_ok

    debug "-- manage_user_stub stub_src : $stub_src"
    debug "   manage_user_stub stub_dst : $stub_dst"
    debug "   manage_user_stub stub_tar : $stub_tar"

    if [ "$action" = uninstall ]; then

        # DO NOT DELETE shell stub, but remove target
        if is_required_stub "$topic"; then
            stub_tar="not-installed-${stub_name}.symlink"

        # delete the stub file
        elif [ -f "$stub_dst" ]; then
            rm "$stub_dst"
            success_or_fail $? "remove" "stub file:" "${topic}/$stub_name"
            return
        fi
    fi

    # Create action (no user stub)
    if ! [ -f "$stub_dst" ]; then
        file_action="create"

    # Update action (ABORT if up to date unless data_update)
    elif [ "$data_mode" != "update" ]; then
        local target_ok="$( [ "$stub_tar" ] && grep "$stub_tar" "$stub_dst" )"
        # Abort if stub_dst is newer then source and has correct target
        if ! [ "$force" ] && [ "$stub_dst" -nt "$stub_src" ] && [ "$target_ok" ]; then
            debug "-- create_user_stub ABORTED (up to date): $stub_src"
            success "Stub file up to date:" "${topic}/$stub_name"
            return
        fi
    fi

    # CREATE output file & temp file
    local stub_tmp="${stub_src}.tmp"
    local stub_out="${stub_src}.out"
    cp -f "$stub_src" "$stub_out"

    local output

    # STUB_TARGET

    debug "   create_user_stub update target"
    grep -q '{STUB_TARGET}' "$stub_out"
    if [ $? -eq 0 ]; then
        local prefix

        # Use load_source_file for shell topics
        if is_shell_topic; then
            prefix="load_source_file "
        fi

        sed -e "s|{STUB_TARGET}|$prefix'$stub_tar'|g" "$stub_out" > "$stub_tmp"
        mv -f "$stub_tmp" "$stub_out"

        if ! [ "$target_ok" ];then
            output="
            $spacer Stub Target : ${stub_tar}"
        fi

    fi

    # ADD USER VARS
    local user_vars
    collect_user_data "$action" "$topic" "$stub_out" "$stub_tmp" "$data_mode" "$force"
    if [ "$user_vars" ]; then
        output="$output\n$user_vars"
    fi

    # move to .dotsys/user/stubs/stubname.topic.stub
    mv -f "$stub_out" "$stub_dst"
    local ret=$?

    # ADD SOURCES

    local sources
    sources="$(collect_topic_sources "install" "$topic" "$stub_name")"
    if [ "$sources" ]; then
        output="$output\n$sources"
    fi

    # TEST IF CURRENT SHELL FILES NEED TO BE RESOURCED
    debug "manage_user_stub $topic -> flag reload"
    RELOAD_SHELL="$(shell flag_reload "$topic" "$RELOAD_SHELL")"

    success_or_fail $ret "$file_action" "stub file:" "${topic}/$stub_name" "$output"
}

# Collects user data and populates stub file
# All modified vars are supplied to $user_vars
# Do not encapsulate this function in a subshell !
collect_user_data () {

    local action="$1"
    local topic="$2"
    local stub_in="$3"
    local stub_out="$4"
    local data_mode="$5"
    local force="$6"
    local stub_name="$(basename ${stub_in%.stub*})"
    local modified=()

    debug "-- collect user data for : $topic/$stub_name"

    # SHELL INIT VARS
    local init_shell_login="INIT_SHELL=\"$topic .$stub_name login\"; source \"\$(dotsys source init_shell)\" \|\| return"
    local init_shell="${init_shell_login/login}"

    local var
    local variables=($(sed -n 's|[^\$]*{\([A-Z_]*\)}.*|\1|gp' "$stub_in"))
    for var in ${variables[@]}; do
        local val
        local user_input
        local var_type="system"
        local default_val
        local script_val
        local values_script
        local output
        # generic key allows for default values from state ie: user_name vs topic_user_name
        local gen_state_key="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
        gen_state_key="${gen_state_key#topic_}"
        gen_state_key="${gen_state_key#$topic_}"
        # topic specific key
        local t_state_key="${topic}_${gen_state_key}"
        # always use generic key as text
        local var_text="$(echo "$gen_state_key" | tr '_' ' ')"

        case "$var" in
            SOURCE_FILES )              continue ;;
            STUB_TARGET )               continue;;

            INIT_SHELL )                val="$init_shell"
                                        var_type="hidden" ;;
            INIT_SHELL_LOGIN )          val="$init_shell_login"
                                        var_type="hidden" ;;

            DOTSYS_DIR )                val="$(dotsys_dir)";;
            DOTSYS_USER_BIN )           val="$(dotsys_user_bin)";;
            DOTFILES_DIR )              val="$(dotfiles_dir)";;

            DOTSYS_PLATFORM )           val="$(get_platform)";;
            DOTSYS_PLATFORM_SPE )       val="$(specific_platform "$(get_platform)")";;
            DOTSYS_PLATFORM_GEN )       val="$(generic_platform "$(get_platform)")";;

            PLATFORM_USER_HOME )        val="$(platform_user_home)";;
            PLATFORM_USER_BIN )         val="$(platform_user_bin)";;

            *)                          val="$(get_state_value "user" "$t_state_key")"
                                        var_type="user" ;;
        esac

        debug "   collect_user_data for $var: state val ($t_state_key = $val)"

        # Check if stubfile.vars supplies values
        if ! [ "$val" ]; then
            values_script="$(get_user_or_builtin_file "$topic" "${stub_name}.vars")"
            debug "   collect_user_data: values_script = $values_script"
            if script_func_exists "$values_script" "$gen_state_key"; then

                script_val="$($values_script $gen_state_key)"

                # value was obtained and no user confirm required
                if [ $? -eq 0 ]; then
                    var_type="system"
                    val="$script_val"
                # got value, requires user confirm
                else
                    default_val="$script_val"
                    var_type="user"
                fi

                debug "   collect_user_data: $var_type script val = $script_val"
            else
                debug "   collect_user_data: values_script func exit code($?)"
            fi
        fi

        # Get user input if no val found (use force to recollect all values)
        if [ "$var_type" = "user" ] && [[ ! "$val" || "$force" = "--force" && "$data_mode" = "collect" ]]; then

            default_val="${val:-$default_val}"

            # use gen_state_key value as default if no val
            if ! [ "$default_val" ]; then
                default_val="$(get_state_value "user" "${gen_state_key}")"
                debug "   collect_user_data get default: $gen_state_key = $default_val"
            fi

            get_user_input "What is your $topic $var_text for $stub_name?" --options "omit" --default "${default_val}" -r
            if ! [ $? -eq 0 ]; then return;fi
            user_input="${user_input:-$def}"
            # set user provided value
            val="${user_input:-$def}"

            # record user val to state
            set_state_value "user" "$t_state_key" "$val"
        fi

        # Freeze user data
        if [ "$action" = "freeze" ];then
            freeze_msg "$var_type data" "$var_text = $val"

        # Replace stub variable with value
        elif [ "$stub_out" ]; then
            local escaped_val="$(echo "$val" | escape_sed)"
            sed -e "s|{$var}|$escaped_val|g" "$stub_in" > "$stub_out"
            mv -f "$stub_out" "$stub_in"
            if [ "$var_type" != "hidden" ];then
                modified+=("$spacer $var_type data : $var_text=$val")
            fi

        # Output user data
        elif [ "$var_type" = "user" ];then
            success "$topic $var_text = $val"
        fi

    done

    user_vars="$(printf '%s\n' "${modified[@]}")"
}

# Collect stub files for a topic
get_topic_stub_sources(){
    local topic="$1"
    echo "$(get_user_or_builtin_file "$topic" "*.stub")"
}


# Determines target for a stub file
# verify "user" return null if no user file.symlink
# verify "repo" return null if no user primary repo
# existing dotfile or user/repo/file.symlink
get_topic_stub_target(){
    local topic="$1"
    local stub_src="$2"
    local verify="$3"
    local user_topic_dir="$(topic_dir "$topic" "user")"
    local stub_src_name="$(basename "$stub_src")"
    local taget_file_name="${stub_src_name%%.*}.symlink"

    # Path to user repo file.symlink
    local stub_target="$user_topic_dir/$taget_file_name"

    debug "-- get_topic_stub_target from: $stub_src"
    debug "   user_topic_dir: $user_topic_dir"
    debug "   target_file_name: $taget_file_name"
    debug "   stub_target: $stub_target"

    # verify user repo file.symlink
    if [ "$verify" = "user" ] && ! [ -f "$stub_target" ]; then
        debug "   -> from user : NOT FOUND $stub_target"
        return 1
    fi

    # Verify we get a user repo path when not topic dir
    if [ "$verify" = "repo" ] && ! [ "$user_topic_dir" ]; then
        local primary_repo="$(state_primary_repo)"
        if [ -d "$primary_repo" ];then
            stub_target="$(topic_dir "$topic" "primary")/$taget_file_name"
        else
            stub_target=
        fi
        debug "   -> from primary : $stub_target"
    fi

    # Exiting dst file or existing user repo file.symlink or none
    if ! [ "$verify" ] && ! [ -f "$stub_target" ] && in_limits "dotsys" -r;then
        # Check for existing stub target (non symlink)
        stub_target="$(get_symlink_dst "$stub_src")"
        if ! [ -L "$stub_target" ] && [ -f "$stub_target" ];then
            stub_target="${stub_target}.dsbak"

        # User file does not exist and no existing file
        else
            stub_target=
        fi

        debug "   -> from existing : $stub_target"
    fi

    echo "$stub_target"
}

# returns the symlink target for a user tub file
# See get_topic_stub_target for options
get_user_stub_target(){
    local verify="$2"
    # empty if user topic does not exist
    echo "$(get_topic_stub_target $(split_user_stub_name "$1") "$verify")"
}

update_user_stub_target () {
    local user_stub="$1"
    local current_target="$2"
    local new_target="$2"
    replace_file_string "$user_stub" "$current_target" "$new_target"
}

# split user stub name file.topic.stub
split_user_stub_name () {
    local stub_name="$(basename "$1")"
    # split parts [0]stub_file [1]stub_topic [2]stub_ext
    local parts=( ${stub_name//./ } )
    # return "topic file_name"
    echo "${parts[1]} ${parts[0]}"
}

# Convert a stub file to user stub file name
get_user_stub_file() {
    local topic="$1"
    local stub_src="$2"
    local stub_name="$(basename "${stub_src%.*}")"
    echo "$(user_stub_dir)/${stub_name}.${topic}.stub"
}

# this is for git, may be useful else where..
get_credential_helper () {
    local helper='cache'
    if [[ "$PLATFORM" == *"mac" ]]; then
        helper='osxkeychain'
    fi
    echo "$helper"
}

# Check all installed topics for files with topic extension
# only new sources written to file & returned
# freeze action outputs all found files
collect_topic_sources () {
    local action="$1"
    local topic="$2"
    local stub_file_name="$3"

    # check if topic has a .sources file
    local topic_sources_script="$(get_user_or_builtin_file "$topic" "${stub_file_name}.sources")"
    if ! [ "$topic_sources_script" ]; then continue;fi

    local installed_topic_dirs="$(get_installed_topics "dir")"
    local order="path functions aliases"
    local src_file
    local dir
    local all_sourced_files=()

    debug "-- add_topic_sources to: $topic/$stub_file_name"

    # Source topic extensions from all installed topics
    for dir in $installed_topic_dirs; do
        local sourced=()
        local o
        debug "   - checking $topic for sources: $dir"
        # source ordered files with topic extension
        for o in $order; do
            src_file="$(find "$dir" -mindepth 1 -maxdepth 1 -type f -name "$o.$topic" -not -name '\.*' )"
            if ! [ -f "$src_file" ]; then continue; fi
            manage_source "$action" "$topic" "$src_file"
            sourced+=("$src_file")
            all_sourced_files+=("$src_file")
        done

        # source topic extension with any name
        local files="$(find "$dir" -mindepth 1 -maxdepth 1 -type f -name "*.$topic" -not -name '\.*' )"
        while IFS=$'\n' read -r src_file; do
            if ! [ -f "$src_file" ] || [[ ${sourced[@]} =~ $src_file ]]; then continue;fi
            manage_source "$action" "$topic" "$src_file"
            all_sourced_files+=("$src_file")
        done <<< "$files"
    done

    # Freeze all source files
    if [ "$action" = "freeze" ] && [ "$all_sourced_files" ];then
        freeze_msg "sourced files" "$stub_file_name" "$(printf "%s\n" "${all_sourced_files[@]}")"
    fi
}

# Check current topic for other topic sources
# new sources writen to file
# removed sources removed from file
manage_topic_source_files () {
    local action="$1"
    local topic="$2"
    #TODO: manage_topic_source_files append builtin sources to user sources
    local topic_files="$(find "$(topic_dir "$topic")" -mindepth 1 -maxdepth 1 -type f -not -name '\.*' )"
    local topic_file
    local target_topic

    debug "-- manage_topic_source_files: $action $topic"

    local src_files=()

    # iterate all files in topic dir
    while IFS=$'\n' read -r topic_file; do
        # source topic is the file extension
        target_topic="${topic_file##*.}"

        # Skip system extensions
        if [[ "$SYSTEM_FILE_EXTENSIONS" =~ $src_topic ]]; then continue;fi

        # make sure topic is installed
        if ! in_state "dotsys" "$target_topic"; then continue;fi

        manage_source "$action" "$target_topic" "$topic_file" "output_status"
        src_files+=("$topic_file")
    done <<< "$topic_files"

    local prev_sourced_file="$(user_stub_dir)/sources_from_${topic}"

    if [ "$action" = uninstall ] || ! [ "$src_files" ] ;then
        if [ -f "$prev_sourced_file" ]; then
            rm "$prev_sourced_file"
        fi
        return
    fi

    # Remove any deleted source files from active sources
    while IFS='' read -r topic_file || [[ -n "$topic_file" ]]; do
        target_topic="${topic_file##*.}"
        debug "   - checking array contains $target_topic $topic_file "
        if ! array_contains src_files "$topic_file";then
            manage_source uninstall "$target_topic" "$topic_file" "output_status"
        fi
    done <"$prev_sourced_file"

    if [ "$src_files" ]; then
        # Add all src_files to prev_sourced_file
        printf "%s\n" "${src_files[@]}" > "$prev_sourced_file"
    fi

}

# Add/remove source from stub file
# Checks if current shel requires resourcing
manage_source () {
    local action="$1"
    local target_topic="$2"
    local src_file="$3"
    local output_status="$4"
    local src_file_name="$(basename "${src_file%.*}")"

    # check if src_file_name has a .sources file
    local format_script="$(get_user_or_builtin_file "$target_topic" "*.sources")"
    if ! [ $? ]; then return; fi

    debug "   - manage_source for: $target_topic/$src_file_name
         \r     with script: $format_script"

    local write_target="$(get_user_stub_file "$target_topic" "$format_script")"
    local formatted_source="$($format_script format_source_file "$src_file")"
    local modified

    # Add a debug command to shell topic sources
    if is_shell_topic; then
        formatted_source="load_source_file '$src_file'"
    fi

    # REMOVE FROM FILE
    if [ "$action" = "uninstall" ];then
        replace_file_string "$write_target" "$formatted_source" ""
        success_or_fail $? "remove" "source $src_file \n$spacer from -> $write_target"
        modified="remove"

    # output all sources to terminal
    elif [ "$action" = "freeze" ] && [ "$output_status" ];then
        freeze_msg "source" "$src_file"

    # WRITE TO FILE
    elif ! grep -q "$src_file" "$write_target"; then
        # Add source to target file
        echo "$formatted_source" >> $write_target
        modified="add"
    fi

    if [ "$modified" ]; then

        debug "manage_source $target_topic -> flag reload"
        RELOAD_SHELL="$(shell flag_reload "$target_topic" "$RELOAD_SHELL")"

        if [ "$output_status" ];then
            success_or_fail $? "$modified" "source $src_file \n$spacer to -> $write_target"
        else
            echo "$spacer ${modified}ed source : $src_file"
        fi
    fi
}

is_stub_file () {
    [ "$1" != "${1%.stub}" ]
}