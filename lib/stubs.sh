#!/usr/bin/env bash

# TODO: IMPLIMENT STUBS (GIT IS DONE)
# CONCEPT NOTES:
# stubs and tempaltes go into the builtins directoy
# builtin stubs copied into the internal user directory during stub process
# if a template is detected the template script will run (custom user info)
# user symlinks are symlinked into internal user directory
# finally stub in internal user directly (original file) is symlinked to destination

# If home directory has a file matching stub we move it to topic directory if no topic/topic symlink exists
# if a topic symlink already exists in topic add new symlink options:
# A file named 'file name' was found, which version do you want to use?
#  - (f)ound (keep found version, move to repo and backup repo version)
#  - (r)epo (keep repo version, backup found, same as existing backup option)
#  - (s)kip
#  - (b)both (copy found version to topic and add to stub file, backup found in home)
#  opt (b) only available with stubbed topics!!!
#  Always backup .. why optional

create_topic_stub () {
    local template=$1
    local stub_name=$2

}