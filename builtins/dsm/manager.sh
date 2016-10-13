#!/usr/bin/env bash

call_dsm(){
    # we must be in topic directory for dest paths
    local topic="$2"
    local topic_dir="$(topic_dir "$topic")"
    cd "$topic_dir"
    if ! [ $? -eq  0 ];then
        shift; shift
        error "The $topic path could not be found:
       $spacer check the dsm setting in $topic's topic.cfg file
       $spacer dsm: $@
       $spacer note: The <name> arg is not permitted!"
        return 1
    fi
    dsm "$@"
}

install () {
    call_dsm install "$@" --link
}

uninstall () {
    call_dsm uninstall "$@"
}

upgrade () {
    call_dsm upgrade "$@"
}

freeze () {
    call_dsm freeze "$@"
}

version () {
    call_dsm version "$@"
}

"$@"
