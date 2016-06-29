#!/usr/bin/sh

install () {

    choco install "$@"
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