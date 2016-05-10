#!/bin/sh

# Homebrew

install () {
  xcode-select --install
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  return $?
}

uninstall () {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
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

$@ # Required for function execution
