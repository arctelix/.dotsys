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
        local stub_files="$(get_topic_stub_files "$topic")"
        local stub_dst
        local stub_target
        local builtin_stub_src
        while IFS=$'\n' read -r builtin_stub_src; do
            debug "src = $builtin_stub_src"
            stub_dst="$(get_symlink_dst "$builtin_stub_src")"
            stub_target="$(get_topic_stub_target "$topic" "$builtin_stub_src")"

            # Check for existing original file only (symlinks will be taken care of during stub process)
            if ! [ -L "$stub_dst" ] && [ -f "$stub_dst" ]; then
                if [ -f "$stub_target" ]; then
                    get_user_input "$(printf "You have two versions of %b$(basename "$stub_dst")%b:
                            $spacer current version: %b$stub_dst%b
                            $spacer dotsys version: %b$stub_target%b
                            $spacer Which version would you like to use with dotsys
                            $spacer (Don't stress, we'll backup the other one)?" $green $rc $green $rc $green $rc)" \
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
                       "$(printf "%bfrom:%b $stub_dst \n$spacer %bto:%b $stub_target" $green $rc $green $rc)"
                fi

                if ! [ $? -eq 0 ]; then continue;fi

                # backup and move system version to dotsys
                cp "$stub_dst" "${stub_dst}.dsbak"
                mkdir -p "$(dirname "$stub_target")"
                mv "$stub_dst" "$stub_target"

            fi
        done <<< "$stub_files"
    done
}

# Collects all required user data at start of process
# Creates stub file in user directory
# The stub is not symlinked to destination until symlink process
manage_stubs () {
    local action="$1"
    local topics=("$2")
    local force="$3"
    local builtins=$(get_dir_list "$(dotsys_dir)/builtins")
    local topic

    debug "-- manage_stubs: $action ${topics[@]} $force"

    if [ "$action" = "uninstall" ] || [ "$action" = "freeze" ]; then return;fi

    # check if user accepted subs and at least one topic
    if ! get_state_value "use_stub_files" "user" || ! [ "${topics[0]}" ]; then
        return
    fi

    if [[ "${topics[@]}" =~ "dotsys" ]]; then
#        load_topic_config_vars "dotsys"
#        local deps="$(get_topic_config_val "dotsys" "deps")"
#        debug "   manage_stubs dotsys deps: $deps"
#        debug "   manage_stubs dotsys deps[@]: ${deps[@]}"
#        topics+=($deps)
         pass
    fi

    if verbose_mode; then
        confirm_task "create" "stub files for" "${topics[@]}"
    fi

    for topic in $builtins; do
        # abort if no user topic directory or if topic is not in current scope
        debug "   manage_stubs topics = ${topics[@]}"
        if ! [ -d "$(topic_dir "$topic")" ] || ! [[ "${topics[@]}" =~ "$topic" ]]; then continue; fi
        create_topic_stubs "$topic" "$action" "$force"
    done
}

# Create all stubs for a topic
create_topic_stubs () {
    local topic="$1"
    local action="$2"
    local force="$3"
    local file

    local stub_files="$(get_topic_stub_files "$topic")"
    if ! [ "$stub_files" ]; then return; fi
    while IFS=$'\n' read -r file; do
        debug "STUBBING TOPIC: $topic file = $file"
        #confirm_task "create" "the stub file for" "${topic}'s $file"
        create_user_stub "$topic" "$file" "$force"
    done <<< "$stub_files"
}

get_topic_stub_files(){
    local topic="$1"
    #TODO: TEST stub files from repos (need to prevent duplicates in stub process)
    local repo_dir="$(topic_dir "$topic")"
    local builtin_dir="$(builtin_topic_dir "$topic")"
    echo "$(find "$repo_dir" "$builtin_dir" -mindepth 1 -maxdepth 1 -type f -name '*.stub' -not -name '\.*')"
}

# returns the stub file symlink target
get_topic_stub_target(){
    local topic="$1"
    local stub_src="$2"
    echo "$(topic_dir "$topic")/$(basename "${stub_src%.stub}.symlink")"
}

# create custom stub file in user/repo/topic
create_user_stub () {

    # stub file variables are defined as {TOPIC_VARIABLE_NAME}
    # ex: {GIT_USER_EMAIL} checks for git_user_email ins state defaults to global user_email
    # ex: {USER_EMAIL} uses global user_email (does not check for topic specif value)

    local topic="$1"
    local stub_src="$2"
    local stub_name="$(basename "${stub_src%.*}")"
    shift; shift
    local force="$3"

    #local stub_src="$(builtin_topic_dir "$topic")/${stub_name}.stub"

    # abort if there is no stub for topic
    if ! [ -f "$stub_src" ]; then
        error "$topic does not have a stub file at:\n$stub_src"
        return
    fi

    local stub_target="$(get_topic_stub_target "$topic" "$stub_src")"
    #local stub_dst="$(topic_dir "$topic")/${stub_name}.stub"
    local stub_dst="$(dotsys_user_stubs)/${stub_name}.${topic}.stub"

    # abort if stub dst exists & is newer then source, unless forced
    if [ -f "$stub_dst" ] && [ "$stub_dst" -nt "$stub_src" ] && ! [ "$force" ]; then return;fi

    debug "-- create_user_stub stub_src : $stub_src"
    debug "   create_user_stub stub_dst : $stub_dst"
    debug "   create_user_stub stub_target : $stub_target"


    # catch dotsys stubs (should not be required but keeping for now)
#    local dotsys_stub
#    if [ "$stub_src" = "$stub_dst" ]; then
#        stub_dst="$(dotsys_user_stubs)/${stub_name}.stub"
#        dotsys_stub="true"
#        debug "   create_user_stub: SOURCE AND DST ARE THE SAME"
#        debug "   create_user_stub new stub_dst    : $stub_dst"
#    fi

    # create temp files
    local stub_out="$(builtin_topic_dir "$topic")/${stub_name}.stub.out"
    local stub_tmp="$(builtin_topic_dir "$topic")/${stub_name}.stub.tmp"

    # Create output file
    cp -f "$stub_src" "$stub_out"

    # set required stub target (for portability no -i option)
    sed  -e "s|{STUB_TARGET}|$stub_target|g" "$stub_out" > "$stub_tmp"
    mv -f "$stub_tmp" "$stub_out"


    local variables="$(sed -n 's|.*[^\$]{\([A-Z_]*\)}.*|\1|gp' "$stub_out")"

    # TODO (IF NEEDED): IF more topic specific variables become common implement topic/*.stub.vars scripts
    # implement topic/*.stub.vars script to provide custom values.
    # get_custom_stub_vars $topic
    # > returns a list of "VARIABLE=some value" pairs
    # variables+="$@"

    local var
    local var_text
    local g_state_key
    local val

    for var in $variables; do
        # global key lower case and remove $topic_ or topic_
        g_state_key="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
        g_state_key="${g_state_key#topic_}"
        g_state_key="${g_state_key#$topic_}"
        # topic key
        t_state_key="${topic}_$g_state_key"
        # always use global key as text
        var_text="$(echo "$g_state_key" | tr '_' ' ')"



        debug "   create_user_stub var($var) key($g_state_key) text($var_text)"

        # check system vars
        if [ "$var" = "DOTSYS_BIN" ]; then
            val="$(dotsys_user_bin)"
        elif [ "$var" = "USER_NAME" ]; then
            val="$USER_NAME"
        elif [ "$var" = "CREDENTIAL_HELPER" ]; then
            val="$(get_credential_helper)"

        # get topic_state_key and set value
        else
            debug "   create_user_stub checking for state key: ${topic}_$g_state_key"
            val="$(get_state_value "$t_state_key" "user")"
        fi

        # DO NOT REMOVE: If required for custom values
        # check for "VARIABLE=some value"
        # if ! [ "$val" ]; then
        #   var="${var#=}" # if no value result wil be var
        #   val="${var%=}" # if no value result wil be var
        #   if [ "$var" = "$val"  ]; then val="";fi
        # fi

        debug "   create_user_stub pre user $var = $val "

        # Get user input if no val found
        if ! [ "$val" ]; then
            # use global_state_key value as default
            debug "   create_user_stub get default: $g_state_key"
            def="$(get_state_value "${g_state_key}" "user" || "non")"

            local user_input
            get_user_input "What is your $topic $var_text for $stub_name?" --options "omit" --default "$def"

            # abort stub process
            if ! [ $? -eq 0 ]; then return;fi

            # set user provided value
            val="${user_input:-$def}"

            # record user val to state
            set_state_value "${topic}_state_key" "$val" "user"
        fi

        # modify the stub variable
        sed -e "s|{$var}|$val|g" "$stub_out" > "$stub_tmp"
        mv -f "$stub_tmp" "$stub_out"

    done

    # move to dotsys_user_stubs/stubname.topic.stub
    #mkdir -p "$(dirname "$stub_dst")"
    mv -f "$stub_out" "$stub_dst"

    if ! is_installed "dotsys" "$topic" --silent; then
        success_or_fail $? "create" "$(printf "stub file for %b$topic $stub_name%b:
            $spacer ->%b$stub_dst%b" $green $rc $green $rc)"
    fi

}


# this is for git, may be useful else where..
get_credential_helper () {
    local helper='cache'
    if [[ "$PLATFORM" == *"mac" ]]; then
        helper='osxkeychain'
    fi
    echo "$helper"
}

# TODO: topic/stubfile.sh will likely be needed
# this works for shell script config files
# need solution for topics like vim with own lang
# use shell script to append source_topic_files to stub..
source_topic_files () {
    local topic="$1"
    local installed_topics="$(get_installed_topic_paths)"
    local src_cmd="${2:-source}"
    local t_dir
    debug "-- source_topic_files for: $topic"
    for t_dir in $installed_topics; do
        local files="$(find "$t_dir" -mindepth 1 -maxdepth 1 -type f -name "*.$topic" -not -name '\.*' )"
        local file
        debug "  source_topic_files from: $t_dir"
        while IFS=$'\n' read -r file; do
            debug "   source_topic_files file: $file"
            $src_cmd "$file"
        done <<< $files
    done
}

SYSTEM_SH_FILES="manager.sh topic.sh install.sh update.sh upgrade.sh freeze.sh uninstall.sh"