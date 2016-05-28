#!/bin/sh

# Homebrew

install () {
  if ! xcode-select --install >/dev/null 2>&1 | grep installed >/dev/null 2>&1 ; then
    xcode-select --install
  fi

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

"$@" # Required for function execution

