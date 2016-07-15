#!/bin/bash

install () {
  dsudo apt-get install "$@"
}

uninstall () {
  dsudo apt-get remove "$@"
}

update () {
  dsudo apt-get update "$@"
}

upgrade () {
  dsudo apt-get dist-upgrade "$@"
}

search () {
  apt-cache search "$@"
}

"$@"



