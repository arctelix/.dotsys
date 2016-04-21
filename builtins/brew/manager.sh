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

#test_install () {
#  local list="${1:-$(get_package_list "brew")}"
#  test_brew "$list"
#}
#
#test_brew (){
#  echo all: "$@"
#  echo 1: "$1"
#  echo 2: "$2"
#}


