#!/bin/sh

install () {
  brew tap caskroom/cask
}

uninstall () {
  brew untap caskroom/cask
}

upgrade () {
  brew cask upgrade
}

update () {
  brew cask update
}

freeze () {
  brew cask list
}

$@ # Required for function execution

