#!/bin/bash

install () {
  brew tap caskroom/cask
  return $?
}

uninstall () {
  brew untap caskroom/cask
  return $?
}

upgrade () {
  brew cask upgrade
  return $?
}

update () {
  brew cask update
  return $?
}

freeze () {
  brew cask list
  return $?
}

$@ # Required for function execution

