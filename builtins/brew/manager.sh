#!/bin/sh

install () {
  echo "manager.sh install got: $@"
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



