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
# Creates stub file in .dotsys/user/stub directory
# Stubs do not get symlinked untill topic is installed.
# However, since stubs are symlinked to user directory
# changes are instant and do not need to be relinked!
manage_stubs () {
    local action="$1"
    local topics=("$2")
    local force="$3"
    local builtins=$(get_dir_list "$(dotsys_dir)/builtins")
    local topic

    if [ "$action" = "uninstall" ] || [ "$action" = "freeze" ]; then return;fi

    # check if user accepted subs and at least one topic
    if ! get_state_value "user" "use_stub_files" || ! [ "${topics[0]}" ]; then
        return
    fi

    # Add dotsys deps to topics when topic is dotsys
    if [[ "${topics[@]}" =~ "dotsys" ]]; then
        load_topic_config_vars "dotsys"
        local deps="$(get_topic_config_val "dotsys" "deps")"
        topics+=($deps)
    fi

    debug "-- manage_stubs: $action ${topics[@]} $force"

    # Confirming stubs seems unnecessary since we get permission during user config
    if verbose_mode; then
        #confirm_task "create" "stub files for" "\n$(echo "${topics[@]}" | indent_list)"
        task "Managing stub files"
    fi

    for topic in $builtins; do
        # abort if no user topic directory or if topic is not in current scope
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
    local topic_dir="$(topic_dir "$topic")"
    local builtin_dir="$(builtin_topic_dir "$topic")"
    local dirs="$topic_dir $builtin_dir"
    local result="$(find $dirs -mindepth 1 -maxdepth 1 -type f -name '*.stub' -not -name '\.*' | sort -u)"
    echo "$result"
}

# returns the stub file symlink target
get_topic_stub_target(){
    local topic="$1"
    local stub_src="$2"
    echo "$(repo_dir)/$topic/$(basename "${stub_src%.stub}.symlink")"
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

    # Convert stub_name to stub_src if required
    # This allows: create_user_stub "git" "gitconfig"
    if [ "$stub_src" = "$stub_name" ] ; then
        stub_src="$(builtin_topic_dir "$topic")/${stub_name}.stub"
    fi

    # abort if there is no stub for topic
    if ! [ -f "$stub_src" ]; then
        error "$topic does not have a stub file at:\n$stub_src"
        return
    fi

    local stub_target="$(get_topic_stub_target "$topic" "$stub_src")"
    local stub_dst="$(dotsys_user_stub_file "$topic" "$stub_src")"

    local mode="create"

    # If stub exists were in update mode
    if ! [ "$force" ]  && [ -f "$stub_dst" ]; then
        # Abort if stub_dst is newer then source and has correct target (everything is correct)

        if [ "$stub_dst" -nt "$stub_src" ] && grep -q "$stub_target" "$stub_dst" ; then return;fi
        mode="update"
    fi

    debug "-- create_user_stub stub_src : $stub_src"
    debug "   create_user_stub stub_dst : $stub_dst"
    debug "   create_user_stub stub_target : $stub_target"


    # catch dotsys stubs (should not be required but keeping for now)
#    local dotsys_stub
#    if [ "$stub_src" = "$stub_dst" ]; then
#        stub_dst="$(dotsys_user_stub_dir)/${stub_name}.stub"
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

    #source_topic_files "$topic" "$stub_out"

    local variables="$(sed -n 's|[^\$]*{\([A-Z_]*\)}.*|\1|gp' "$stub_out")"

    # TODO (IF NEEDED): IF more topic specific variables become common implement topic/*.stub.vars scripts
    # implement topic/*.stub.vars script to provide custom values.
    # get_custom_stub_vars $topic
    # > returns a list of "VARIABLE=some value" pairs
    # variables+="$@"

    local var
    local var_text
    local g_state_key
    local val
    local user_var

    debug "   create_user_stub variables: $variables"

    for var in $variables; do
        # global key lower case and remove $topic_ or topic_
        g_state_key="$(echo "$var" | tr '[:upper:]' '[:lower:]')"
        g_state_key="${g_state_key#topic_}"
        g_state_key="${g_state_key#$topic_}"
        # topic key
        t_state_key="${topic}_${g_state_key}"
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

        elif [ "$var" = "SOURCE_FILES" ]; then
            val=""
            source_topic_files "$topic" "$stub_out"

        elif [ "$var" = "DOTFILES_DIR" ]; then
            val="$(dotfiles_dir)"

        elif [ "$var" = "DOTSYS_DIR" ]; then
            val="$(dotsys_dir)"

        elif [ "$var" = "DOTSYS_PLATFORM" ]; then
            val="$(specific_platform "$(get_platform)")"

        elif [ "$var" = "DOTSYS_PLATFORM_GEN" ]; then
            val="$(generic_platform "$(get_platform)")"

        # get topic_state_key and set value
        else
            debug "   create_user_stub checking for state key: ${topic}_$g_state_key"
            val="$(get_state_value "user" "$t_state_key")"
            user_var="true"
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
        if ! [ "$val" ] && [ "$user_var" ]; then
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

        # modify the stub variable
        sed -e "s|{$var}|${val}|g" "$stub_out" > "$stub_tmp"
        mv -f "$stub_tmp" "$stub_out"

    done

    # move to .dotsys/user/stubs/stubname.topic.stub
    mv -f "$stub_out" "$stub_dst"
    local status=$?

#    if ! is_installed "dotsys" "$topic" --silent; then
#        removed success_or_fail from here
#    fi

    success_or_fail $status "$mode" "stub file for" "$(printf "%b$topic $stub_name:" $thc )" \
            "\n$spacer ->$stub_dst"

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
    local stub_file="$2"
    local installed_paths="$(get_installed_topic_paths)"
    local file
    local topic_dir
    local OWD="$PWD"

    local order="path functions aliases"

    local files

    for topic_dir in $installed_paths; do
        local sourced=()
        local o

        #cd "$topic_dir"

        # source ordered files
        for o in $order; do
            file="$(find "$topic_dir" -mindepth 1 -maxdepth 1 -type f -name "$o.$topic" -not -name '\.*' )"
            if ! [ "$file" ]; then continue; fi
            echo source "$file" >> $stub_file
            #echo "  - sourced $file"
            sourced+=("$file")
        done

        # source topic files of any name
        local topic_files="$(find "$topic_dir" -mindepth 1 -maxdepth 1 -type f -name "*.$topic" -not -name '\.*' )"
        while IFS=$'\n' read -r file; do
            if ! [ "$file" ] || [[ ${sourced[@]} =~ $file ]]; then continue;fi
            echo source "$file" >> $stub_file
            #echo "  - sourced $file"
        done <<< "$topic_files"
    done

    #echo $(echo "$files" | tr '\n' "\\n")

    #cd "$OWD"
}

SYSTEM_SH_FILES="manager.sh topic.sh install.sh update.sh upgrade.sh freeze.sh uninstall.sh"