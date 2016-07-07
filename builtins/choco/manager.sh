#!/bin/sh

install () {
    choco install "$@"
    cmd
    refreshenv
}

uninstall () {
    choco uninstall "$@"
}

upgrade () {
    choco upgrade "$@"
}

freeze () {
    choco list "$@"
}

search () {
    choco search "$@"
}

"$@"