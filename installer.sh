#!/bin/sh

# TODO ROADMAP: Enable download of dotsys repo from installer script.

cd "$(dirname "$0")"
export DOTSYS_REPOSITORY="$PWD"
export DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"

dotsys_installer () {

    source "$DOTSYS_LIBRARY/main.sh"

    local usage="dotsys_installer <action>"
    local usage_full="Installs and uninstalls dotsys.
    1) Extract the .dotsys directory to the location you want to install it and run this script.
    install        install dotsys
    uninstall      uninstall dotsys
    --debug        turn on debug mode
    "

    export ACTIVE_SHELL="${SHELL##*/}"
    export ACTIVE_LOGIN_SHELL="$ACTIVE_SHELL"

    local action
    local force

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

    action="${action:-install}"

    print_logo

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

    # make sure PLATFORM_USER_BIN is on path
    if [ "${PATH#*$PLATFORM_USER_BIN}" == "$PATH" ]; then
        export PATH=$PATH:/usr/local/bin
        debug "added /usr/local/bin to path: $PATH"
    fi

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

        # some initial values for user state
        state_install "user" "show_stats" "0"
        state_install "user" "show_logo" "0"

        # Add dotsys/bin files to usr/bin
        manage_topic_bin link core
    fi

    # install dotsys deps
    dotsys $action dotsys --confirm default "$force"

    # Remove dotsys/bin files from usr/bin
    if [ "$action" = "uninstall" ]; then
        manage_topic_bin unlink core
    fi

    msg "\nDotsys has been ${action%e}ed
         \rThanks for using dotsys!\n"

    if [ "$action" = "install" ]; then
        dotsys "$action" from ""
    fi
}

dotsys_installer $@