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

search () {
  brew search "$@" -y
}

"$@"



