#!/bin/bash

install () {
  brew install "$@"
}

uninstall () {
  brew uninstall "$@"
}

upgrade () {
  local r
  brew upgrade "$@"
}

"$@"



