#!/bin/sh

install () {
    pact install "$@"
}

uninstall () {
    pact remove "$@"
}

upgrade () {
    pact update "$@"
}

freeze () {
    pact show "$@"
}

search () {
    pact find "$@"
}

"$@"