#!/bin/bash

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

"$@"



