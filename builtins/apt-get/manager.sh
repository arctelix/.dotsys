#!/bin/bash

install () {
  dsudo apt-get install -y "$@"
}

uninstall () {
  dsudo apt-get remove -y "$@"
}

update () {
  dsudo apt-get update "$@"
}

upgrade () {
  dsudo apt-get dist-upgrade -y "$@"
}

search () {
  apt-cache search "$@"
}

"$@"



