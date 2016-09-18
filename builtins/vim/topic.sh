#!/bin/sh

install () {

    # create mvim -> vim symlinks
    if [ "$PLATFORM" = "linux-mac" ] && [ -f "/usr/local/bin/mvim" ]; then

        local pub="$PLATFORM_USER_BIN"
        ln -sf $pub/mvim $pub/vim
        success_or_fail $? "Add" "vim -> mvim symlink"
        ln -sf $pub/mvim $pub/gvim
        success_or_fail $? "Add" "gvim -> mvim symlink"

    fi

}

uninstall () {

    # remove mvim -> vim symlinks
    if [ "$PLATFORM" = "linux-mac" ] && ! [ -f "/usr/local/bin/mvim" ]; then

        local pub="$PLATFORM_USER_BIN"
        if [ -L "$pub/vim" ] && ! [ -f "$pub/vim" ]; then
            rm $pub/vim
            success_or_fail $? "Remove" "vim -> mvim symlink"
        fi

        if [ -L "$pub/gvim" ] && ! [ -f "$pub/gvim" ]; then
            rm $pub/gvim
            success_or_fail $? "Remove" "gvim -> mvim symlink"
        fi
    fi

    # Remove .vim directory
    if [ -d "~/.vim" ]; then
        rm ~/.vim
        success_or_fail $? "Remove" "~./vim"
    fi

}

"$@"