#!/bin/sh

install () {
  brew cask install $@
}

uninstall () {
  brew cask uninstall $@
}

upgrade () {
  brew cask upgrade $@
}

$@ # Required for function execution
