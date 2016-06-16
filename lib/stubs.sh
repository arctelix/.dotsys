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
            stub_target="$(get_topic_stub_target "$topic" "$stub_src")"
            #user_stub_file="$(dotsys_user_stub_file "$topic" "$stub_src")"

            # Check for existing original file only (symlinks will be taken care of during stub process)
            if ! [ -L "$stub_dst" ] && [ -f "$stub_dst" ]; then
                if [ -f "$stub_target" ]; then
                    get_user_input "$(printf "You have two versions of %b$(basename "$stub_dst")%b:
                            $spacer current version: %b$stub_dst%b
                            $spacer dotsys version: %b$stub_target%b
                            $spacer Which version would you like to use with dotsys
                            $spacer (Don't stress, we'll backup the other one)?" $thc $rc $thc $rc $thc $rc)" \
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
                       "$(printf "%bfrom:%b $stub_dst" $thc $rc )" \
                       "$(printf "%bto:%b $stub_target" $thc $rc )"
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
    usage="manage_stubs [<option>]"
    usage_full="
        -f | --force        Force stub updates
        -d | --data         Collect user data only
        -t | --task         Show task messages
    "

    local action="$1"
    local topics=("$2")
    shift; shift

    #local builtins=$(get_dir_list "$(dotsys_dir)/builtins")
    local topic
    local force
    local mode

    while [[ $# > 0 ]]; do
        case "$1" in
        -f | --force )      force="$1" ;;
        -d | --data )       mode="$1" ;;
        -t | --task )       mode="$1" ;;
        *)  invalid_option ;;
        esac
        shift
    done

    if [ "$action" = "uninstall" ] || [ "$action" = "freeze" ]; then return;fi

    # check if user accepted subs and at least one topic
    if ! get_state_value "user" "use_stub_files" || ! [ "${topics[0]}" ]; then
        return
    fi

    debug "-- manage_stubs: $action ${topics[@]} $mode $force"

    if [ "$mode" = "--data" ]; then
        task "Collecting user data"
    elif [ "$mode" = "--task" ];then
        task "Managing stub files"
    fi

    for topic in ${topics[@]}; do
        # Abort if no user topic unless topic is core or shell
        if ! [[ "${topics[*]}" =~ (core|shell) ]] && ! [ -d "$(topic_dir "$topic" "user")" ]; then continue; fi
        manage_topic_stubs "$action" "$topic" "$mode" "$force"
    done

    # Core Always gets updated
    manage_topic_stubs "$action" "core" "$mode"
    # Shell always gets updated for sourcing topic .shell files
    manage_topic_stubs "$action" "shell" "$mode"

}

# Create all stubs for a topic
manage_topic_stubs () {
    usage="manage_topic_stubs [<option>]"
    usage_full="
        -f | --force        Force stub updates
        -d | --data         Collect user data only
        -t | --task         Show task messages
    "
    local action="$1"
    local topic="$2"

    shift; shift

    local force
    local mode
    local stub_file

    while [[ $# > 0 ]]; do
        case "$1" in
        -f | --force )      force="$1" ;;
        -t | --task )       mode="task" ;;
        -d | --data )       mode="data" ;;
        *)  invalid_option ;;
        esac
        shift
    done

    # check if user accepted subs
    if ! get_state_value "user" "use_stub_files"; then return; fi

    # Check for topic stub files
    local stub_files="$(get_topic_stub_sources "$topic")"
    if [ "$stub_files" ];then
        debug "-- manage_topic_stubs: $action $topic $mode $force"

        if [ "$mode" = "task" ]; then
            task "Stubbing $topic $mode"
        fi

        while IFS=$'\n' read -r stub_file; do
            debug "   found stub file for $topic -> $stub_file"

            if [ "$mode" = "data" ]; then
                collect_user_data "$action" "$stub_file" "" "$force"
            elif [ "$action" = freeze ];then
                collect_user_data "$action" "$stub_file" "" "$force"
                collect_topic_sources "$action" "$topic" "$(basename "${stub_file%.*}")"
            else
                # Create/Update stub file with target, user data, and source files
                manage_user_stub "$topic" "$stub_file" "$mode" "$force"
            fi
        done <<< "$stub_files"
    fi

    # Make sure source files from topic are added to the appropriate stub file
    manage_topic_source_files "$action" "$topic"
}


# creates custom stub file in user/repo/topic
manage_user_stub () {

    # stub file variables are defined as {TOPIC_VARIABLE_NAME}
    # ex: {GIT_USER_EMAIL} checks for git_user_email ins state defaults to global user_email
    # ex: {USER_EMAIL} uses global user_email (does not check for topic specif value)

    local topic="$1"
    local stub_src="$2"
    local mode="$3"
    local force="$4"

    local stub_name="$(basename "${stub_src%.*}")"
    local file_action="update"

    # Convert stub_name to stub_src if required
    # This allows: create_user_stub "git" "gitconfig"
    if [ "$stub_src" = "$stub_name" ] ; then
        stub_src="$(get_topic_or_builtin_file "$topic" "${stub_name}.stub")"
    fi

    # abort if there is no stub for topic
    if ! [ -f "$stub_src" ]; then
        error "$topic does not have a stub file at:\n$stub_src"
        return
    fi

    local stub_tar="$(get_topic_stub_target "$topic" "$stub_src")"
    local stub_dst="$(get_user_stub_file "$topic" "$stub_src")"
    local target_ok

    debug "-- create_user_stub stub_src : $stub_src"
    debug "   create_user_stub stub_dst : $stub_dst"
    debug "   create_user_stub stub_tar : $stub_tar"

    # Create mode (no user stub or stub src is newer)
    if ! [ -f "$stub_dst" ]; then
        file_action="create"

    # Update mode (collect modified sources & modified target)
    else
        local target_ok="$(grep "$stub_tar" "$stub_dst")"
        # Abort if stub_dst is newer then source and has correct target
        if ! [ "$force" ] && [ "$stub_src" -nt "$stub_dst" ] && [ "$target_ok" ]; then
            debug "-- create_user_stub ABORTED (up to date): $stub_src"
            return
        fi
    fi

    # Create output file
    local stub_tmp="${stub_src}.tmp"
    local stub_out="${stub_src}.out"
    cp -f "$stub_src" "$stub_out"


    # STUB_TARGET
    debug "   create_user_stub update target"
    grep -q '{STUB_TARGET}' "$stub_out"
    if [ $? -eq 0 ]; then
        sed -e "s|{STUB_TARGET}|$stub_tar|g" "$stub_out" > "$stub_tmp"
        mv -f "$stub_tmp" "$stub_out"
        if ! [ "$target_ok" ];then
            output="
            $spacer Stub Target :$stub_tar"
        fi
    fi

    # USER VARS
    collect_user_data "$action" "$stub_out" "$stub_tmp"

    # move to .dotsys/user/stubs/stubname.topic.stub
    mv -f "$stub_out" "$stub_dst"
    local status=$?

    local sources
    sources="$(collect_topic_sources "install" "$topic" "$stub_name")"

    # remove source files var
    if [ "$sources" ]; then
        output="$output\n$sources"
    fi

    success_or_fail $status "$file_action" "stub file:" "${topic}/$stub_name" "$output"
}

collect_user_data () {

    # TODO (IF NEEDED): IF more complex topic specific variables become necessary (like git) implement topic/*.stub.vars scripts to obtain values
    # get_custom_stub_vars $topic   # returns a list of "VARIABLE=value" pairs
    # variables+="$@"               # add "VARIABLE=value" pairs to variables

    debug "-- collect user data variables"
    local action="$1"
    local stub_in="$2"
    local stub_out="$3"
    local force="$4"
    local var
    local val
    local var_text
    local g_state_key
    local t_state_key
    local user_var
    local variables=($(sed -n 's|[^\$]*{\([A-Z_]*\)}.*|\1|gp' "$stub_in"))

    for var in ${variables[@]}; do
        # global key lower case and remove $topic_ or topic_
        g_state_key="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
        g_state_key="${g_state_key#topic_}"
        g_state_key="${g_state_key#$topic_}"
        # topic key
        t_state_key="${topic}_${g_state_key}"
        # always use global key as text
        var_text="$(echo "$g_state_key" | tr '_' ' ')"

        case "$var" in
            SOURCE_FILES )              continue ;;
            STUB_TARGET )               continue;;
            DOTSYS_BIN )                val="$(dotsys_user_bin)";;
            USER_NAME )                 val="$USER_NAME";;
            CREDENTIAL_HELPER )         val="$(get_credential_helper)";;
            DOTFILES_DIR )              val="$(dotfiles_dir)" ;;
            DOTSYS_DIR )                val="$(dotsys_dir)" ;;
            DOTSYS_PLATFORM )           val="$(get_platform)" ;;
            DOTSYS_PLATFORM_SPE )       val="$(specific_platform "$(get_platform)")" ;;
            DOTSYS_PLATFORM_GEN )       val="$(generic_platform "$(get_platform)")" ;;
            *)                          val="$(get_state_value "user" "$t_state_key")"
                                        user_var="true" ;;
        esac

        # DO NOT REMOVE: If required for complex custom values
        # check for "VARIABLE=some value"
        # if ! [ "$val" ]; then
        #   val="${var%=}"                            # split value from "VARIABLE=value"
        #   var="${var#=}"                            # split variable from "VARIABLE=value"
        #   if [ "$var" = "$val"  ]; then val="";fi   # clear value if none provided
        # fi

        debug "   - collect_user_data: var($var) key($g_state_key) text($var_text) = $val"

        # Get user input if no val found
        if [[ ! "$val" && "$user_var" ]] || [ "$force" ]; then
            # use global_state_key value as default
            debug "   create_user_stub get default: $g_state_key"
            local def
            def="$(get_state_value "user" "${g_state_key}")"

            local user_input
            get_user_input "What is your $topic $var_text for $stub_name?" --options "omit" --default "${def:-none}" -r

            # abort stub process
            if ! [ $? -eq 0 ]; then return;fi

            # set user provided value
            val="${user_input:-$def}"

            # record user val to state
            set_state_value "user" "${topic}_state_key" "$val"
        fi

        # Replace stub variable with value
        if [ "$stub_out" ]; then
            sed -e "s|{$var}|${val}|g" "$stub_in" > "$stub_out"
            mv -f "$stub_out" "$stub_in"

        # Freeze user data
        elif [ "$action" = "freeze" ];then
            freeze_msg "user data" "$var_text = $val"

        # Output user data
        else
            success "$topic $var_text = $val"
        fi

    done
}

get_topic_stub_sources(){
    local topic="$1"
    local topic_dir="$(topic_dir "$topic" "active")"
    local builtin_dir="$(topic_dir "$topic" "builtin")"
    local dirs="$topic_dir $builtin_dir"
    local result="$(find $dirs -mindepth 1 -maxdepth 1 -type f -name '*.stub' -not -name '\.*' | sort -u)"
    echo "$result"
}


# returns the stub file symlink target
get_topic_stub_target(){
    local topic="$1"
    local stub_src="$2"

    # stub target should never be the builtin repo
    echo "$(topic_dir "$topic" "user")/$(basename "${stub_src%.stub}.symlink")"
}


# this is for git, may be useful else where..
get_credential_helper () {
    local helper='cache'
    if [[ "$PLATFORM" == *"mac" ]]; then
        helper='osxkeychain'
    fi
    echo "$helper"
}

# Check all installed topics for current topic stub file
collect_topic_sources () {
    local action="$1"
    local topic="$2"
    local stub_file_name="$3"

    # check if topic has a .sources file
    local topic_sources_script="$(get_topic_or_builtin_file "$topic" "${stub_file_name}.sources")"
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
manage_topic_source_files () {
    local action="$1"
    local topic="$2"
    #TODO: manage_topic_source_files append builtin sources to user sources
    local topic_files="$(find "$(topic_dir "$topic")" -mindepth 1 -maxdepth 1 -type f -not -name '\.*' )"
    local src_file

    debug "-- manage_topic_source_files: $action $topic"

    # iterate all files in topic dir
    while IFS=$'\n' read -r src_file; do
        local src_topic="${src_file##*.}"

        # Skip system extensions
        if [[ "$SYSTEM_FILE_EXTENSIONS" =~ $src_topic ]]; then continue;fi

        # make sure topic is installed
        if ! in_state "dotsys" "$src_topic"; then continue;fi

        manage_source "$action" "$src_topic" "$src_file" "output_status"

    done <<< "$topic_files"
}

# Add/remove source from stub file
manage_source () {
    local action="$1"
    local src_file_topic="$2"
    local src_file="$3"
    local output_status="$4"
    local src_file_name="$(basename "${src_file%.*}")"

    # check if src_file_name has a .sources file
    local format_script="$(get_topic_or_builtin_file "$src_file_topic" "*.sources")"
    if ! [ $? ]; then return; fi

    debug "   - manage_source for: $src_file_topic/$src_file_name
        $spacer with script: $format_script"

    local write_target="$(get_user_stub_file "$src_file_topic" "$format_script")"
    local formatted_source="$($format_script format_source_file "$src_file")"

    # remove source on uninstall
    if [ "$action" = "uninstall" ];then
        ex "+g/$formatted_source/d" -cwq "$write_target"
        success_or_fail $? "remove" "$src_file_name" "from $(basename "$write_target")"
        return
    fi

    # Abort if source is already added
    if grep -q "$src_file" "$write_target"; then
        debug "   - manage_source: ABORT already sourced $src_file"

        if [ "$action" = "freeze" ] && [ "$output_status" ];then
            freeze_msg "source" "$src_file"
        fi
        return

    elif [ "$action" = "freeze" ] && [ "$output_status" ];then
        freeze_msg "source (un-sourced)" "$src_file"
        return
    fi

    # Add source to target file
    echo "$formatted_source" >> $write_target

    if [ "$output_status" ];then
        success_or_fail $? "add" "source $src_file \n$spacer -> $write_target"
    else
        echo "$spacer Sourced : $src_file"
    fi

}

