#!/bin/bash

# TODO ROADMAP: Enable download of dotsys repo from installer script.

cd "$(dirname "$0")"
export DOTSYS_REPOSITORY="$PWD"
export DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"

dotsys_installer () {

    # Let main know that we're running from installer
    INSTALLER_RUNNING=true

    chmod -R 755 "$DOTSYS_REPOSITORY"

    source "$DOTSYS_LIBRARY/core.sh"
    source "$DOTSYS_LIBRARY/main.sh"

    local usage="dotsys_installer <action>"
    local usage_full="Installs and uninstalls dotsys.
    1) Extract the .dotsys directory to the location you want to install it and run this script.
    install        install dotsys
    uninstall      uninstall dotsys
    --debug        turn on debug mode
    "

    if ! [ $ACTIVE_SHELL ]; then
        export ACTIVE_SHELL="${SHELL##*/}"
        export ACTIVE_LOGIN_SHELL="$ACTIVE_SHELL"
    fi

    local action
    local force
    local DEBUG="false"

    while [[ $# > 0 ]]; do
        case "$1" in
        install )    action="$1" ;;
        uninstall )  action="$1" ;;
        --debug )  DEBUG="true" ;;
        --force )  force="$1" ;;
        * )  error "Not a valid action: $1"
             show_usage ;;
        esac
        shift
    done

    export DEBUG

    action="${action:-install}"

    print_logo --force

    debug "DOTSYS_REPOSITORY: $DOTSYS_REPOSITORY"
    debug "ACTIVE_SHELL: $ACTIVE_SHELL"
    debug "dotfiles_dir: $(dotfiles_dir)"

    if [ "$action" = "install" ]; then
        msg "Please make sure the .dotsys directory is located in it's
           \rpermanent location before running the installer.
           \rYou can uninstall with '.dotsys/instller.sh uninstall'\n"

        msg "Dotsys Copyright (C) 2016  Arctelix (http://gitbub.com/arctelix)
           \rThis program comes with ABSOLUTELY NO WARRANTY. This is free software,
           \rand you are welcome to redistribute it under certain conditions\n"
    fi

    get_user_input "Would you like to install dotsys?" --confvar ""
    if ! [ $? -eq 0 ]; then  exit; fi


    # create required files and directories
    if [ "$action" = "install" ]; then

        task "Preparing required directories and files"

        mkdir -p "$(dotfiles_dir)"
        mkdir -p "$DOTSYS_REPOSITORY/user/bin"
        mkdir -p "$DOTSYS_REPOSITORY/user/stubs"
        mkdir -p "$DOTSYS_REPOSITORY/state"
        touch "$DOTSYS_REPOSITORY/state/dotsys.state"
        touch "$DOTSYS_REPOSITORY/state/user.state"
        touch "$DOTSYS_REPOSITORY/state/repos.state"
        touch "$DOTSYS_REPOSITORY/state/deps.state"

        success_or_error $? "$action" "dotsys files and directories"

        new_user_config
    fi

    # make sure PLATFORM_USER_BIN is on path
    PLATFORM_USER_BIN="$(platform_user_bin)"
    if [ $? -eq 1 ]; then
        read -p "PLATFORM NOT FOUND PRESS ANY KEY TO ABORT"
        exit 1
    elif [ "${PATH#*$PLATFORM_USER_BIN}" == "$PATH" ]; then
        export PATH="$PLATFORM_USER_BIN:$PATH"
        task "added $PLATFORM_USER_BIN to path: $PATH"
    fi

    # install dotsys deps
    dotsys $action dotsys --confirm default "$force"

    echo
    success_or_error $? "$action" "the dotsys core system"
    echo

    INSTALLER_RUNNING=""
    if [ "$action" = "install" ]; then
        task "Install user repo and topics\n"
        dotsys "$action" from ""
    fi
}

dotsys_installer "$@"