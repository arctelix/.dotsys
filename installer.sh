#!/bin/sh

if ! [ "$DOTSYS_LIBRARY" ];then
    if [ ! -f "$0" ];then
        DOTSYS_REPOSITORY="$(dirname "$BASH_SOURCE")"
    else
        DOTSYS_REPOSITORY="$(dirname "$0")"
    fi
    DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"
fi

dotsys_installer () {

    local usage="dotsys_installer <action>"
    local usage_full="Installs and uninstalls dotsys.
    1) Extract the .dotsys directory to the location you want to install it and run this script.
    install        install dotsys
    uninstall      uninstall dotsys
    --debug        turn on debug mode
    "

    #TODO ROADMAP: Enable download of dotsys repo from installer script.
    source "$DOTSYS_LIBRARY/main.sh"

    local current_shell="${SHELL##*/}"
    local action

    while [[ $# > 0 ]]; do
        case "$1" in
        install )    action="$1" ;;
        uninstall )  action="$1" ;;
        -d | --debug )  DEBUG="true" ;;
        * )  error "Not a valid action: $1"
             show_usage ;;
        esac
        shift
    done

    action="${action:-install}"

    set_user_vars
    print_logo

    debug "DOTSYS_REPOSITORY: $DOTSYS_REPOSITORY"
    debug "current_shell: $current_shell"
    debug "$action dotsys user_dotfiles: "$(dotfiles_dir)""

    if [ "$action" = "install" ]; then
        msg "Please make sure the .dotsys directory is located in it's
           \rpermanent location before running the installer.
           \rYou can uninstall with '.dotsys/instller.sh uninstall'\n"

        msg "Dotsys Copyright (C) 2016  Arctelix (http://gitbub.com/arctelix)
           \rThis program comes with ABSOLUTELY NO WARRANTY. This is free software,
           \rand you are welcome to redistribute it under certain conditions\n"
    fi

    confirm_task "$action" "" "dotsys"
    if ! [ $? -eq 0 ]; then  exit; fi

    # make sure PLATFORM_USER_BIN is on path
    if [ "${PATH#*$PLATFORM_USER_BIN}" == "$PATH" ]; then
        export PATH=$PATH:/usr/local/bin
        debug "added /usr/local/bin to path: $PATH"
    fi

    # create required directories
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
    fi

    # This is the actual installer
    dotsys "$action" dotsys --confirm default

    msg "\nDotsys has been ${action%e}ed
         \rThanks for using dotsys!\n"

    if [ "$action" = "install" ]; then
        dotsys "$action" from ""
    fi
}

dotsys_installer $@




