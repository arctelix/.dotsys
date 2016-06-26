#!/bin/sh

# Run on first init only
if [ ! "$SHELL_INITIALISED" ];then
    DEBUG_SHELL="true"
    source "$(dotsys source core)"
    source "$(dotsys source shell)"
    shell_init $INIT_SHELL
fi


