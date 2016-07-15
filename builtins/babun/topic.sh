#!/bin/bash

install () {

    # Sets $HOME to user's windows home rather then .babun/home/<username>
    setx HOME $env:userprofile

    # now install babun
    choco install babun

    # Remove duplicate sourcing of .zprofile
    replace_file_string '/cygdrive/c/Users/arcte/.babun/cygwin/usr/local/etc/babun.zsh' \
                        'test -f "$homedir/.zprofile" && source "$homedir/.zprofile"' ''
}

"$@"