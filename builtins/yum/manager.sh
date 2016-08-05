#!/bin/bash

install () {
  yum install "$@" -y
}

uninstall () {
  yum remove "$@" -y
}

upgrade () {

  yum update "$@" -y
}

search () {
  yum search "$@" -y
}

"$@"



