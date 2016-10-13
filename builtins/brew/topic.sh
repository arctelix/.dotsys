#!/bin/bash

# Homebrew

install () {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  [ $? -eq 0 ] || return 31
}

uninstall () {
  # make sure brew is empty
  if ! [ "$(brew list)" ]; then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
  fi
  return $?
}

"$@"

