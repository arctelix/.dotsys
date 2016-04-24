#!/bin/sh

install () {
  brew install $@
}

uninstall () {
  brew uninstall $@
}

upgrade () {
  brew upgrade $@
  return $?
}

$@ # Required for function execution



