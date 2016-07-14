#!/bin/sh

install () {
    choco install "$@" --yes
}

uninstall () {
    choco uninstall "$@" --yes
}

upgrade () {
    choco upgrade "$@" --yes
}

freeze () {
    choco list "$@"
}

search () {
    choco search "$@"
}

"$@"