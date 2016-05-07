#!/bin/sh

# Homebrew

install () {
  xcode-select --install
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

uninstall () {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
}

upgrade () {
  brew upgrade
}

update () {
  brew update
}

freeze () {
  brew list
}

$@ # Required for function execution
