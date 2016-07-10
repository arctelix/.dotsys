#!/bin/sh

# Run on first init only
if [ ! "$SHELL_INITIALISED" ];then
    SHELL_FILES_LOADED=()
    source "$(dotsys source core)"
    source "$(dotsys source shell)"
    shell_init $INIT_SHELL

# prevent exteranl script from reloading files
elif [ ! $SHELL_LOADING = "true" ];then
    shell_debug "<< ABORT: already loaded $INIT_SHELL"
    return 1
fi


