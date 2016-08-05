#!/bin/bash

install () {
  pacman -S "$@"
}

uninstall () {
  pacman -R "$@"
}

upgrade () {
  pacman -S "$@"
}

search () {
  pacman -Ss "$@"
}

"$@"



