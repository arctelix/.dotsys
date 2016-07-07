#!/bin/sh

install () {
    npm install npm -g
}

upgrade () {
    install
}

update () {
    install
}

"$@"