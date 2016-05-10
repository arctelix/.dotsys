#!/bin/sh

install () {
  brew cask install $@
  return $?
}

uninstall () {
  brew cask uninstall $@
  return $?
}

upgrade () {
  brew cask upgrade $@
  return $?
}

$@ # Required for function execution
