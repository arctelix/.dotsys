#!/bin/bash

install () {
    choco install "$@" --yes
}

uninstall () {
    choco uninstall "$@" --yes
}

upgrade () {
    choco upgrade "$@" --yes
}

search () {
    choco search "$@"
}

"$@"