#!/bin/bash

install () {
  dsudo yum install "$@" -y
}

uninstall () {
  dsudo yum remove "$@" -y
}

upgrade () {

  dsudo yum update "$@" -y
}

search () {
  dsudo yum search "$@" -y
}

"$@"



