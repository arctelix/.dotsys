#!/bin/bash

install () {
  brew cask install "$@"
  return $?
}

uninstall () {
  brew cask uninstall "$@"
  return $?
}

upgrade () {
  # Currently no upgrade for casks
  msg "$spacer upgrade cask not available use $(code "dotsys install $* --force")"
  return 20
}

"$@" # Required for function execution
