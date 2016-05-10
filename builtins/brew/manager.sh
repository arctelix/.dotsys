#!/bin/sh

install () {
  brew install $@
  return $?
}

uninstall () {
  brew uninstall $@
  return $?
}

upgrade () {
  brew upgrade $@
  return $?
}

$@ # Required for function execution



