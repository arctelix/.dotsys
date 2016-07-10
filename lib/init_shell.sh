#!/bin/sh

# Run on first init only
if [ ! "$SHELL_INITIALISED" ];then
    source "$(dotsys source core)"
    source "$(dotsys source shell)"
    shell_init $INIT_SHELL

# Prevent external scripts from reloading files
elif [ $SHELL_LOADING = "false" ];then
    debug_shell "<< ABORT: already loaded $INIT_SHELL"
    return 1
fi


