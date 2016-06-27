#!/bin/sh

# Homebrew

install () {
  xcode-select --install
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  return $?
}

uninstall () {
  # make sure brew is empty
  if ! [ "$(brew list)" ]; then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
  fi
  return $?
}

upgrade () {
  #brew upgrade would upgrade packages..
  return $?
}

update () {
  brew update
  return $?
}

freeze () {
  brew list
  return $?
}

"$@"

