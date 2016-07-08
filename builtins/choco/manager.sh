#!/bin/sh

install () {
    choco install "$@"
    #TODO: Need a way to add chocolaty paths to cygn path after install
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