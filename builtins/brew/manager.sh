#!/bin/bash

install () {
  brew install "$@" -y
}

uninstall () {
  brew uninstall "$@" -y
}

upgrade () {
  brew upgrade "$@" -y
}

freeze () {
  brew list "$@"
}


update () {
  brew update
}

search () {
  brew search "$@" -y
}

"$@"



