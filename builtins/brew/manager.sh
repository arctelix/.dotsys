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

update () {
  brew update "$@" -y
}

freeze () {
  brew list "$@"
}

search () {
  brew search "$@" -y
}

"$@"



