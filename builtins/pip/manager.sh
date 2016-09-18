#!/bin/bash

# pip/manager.sh

export PIP_REQUIRE_VIRTUALENV=""

install () {
  pip install "$@"
}

uninstall () {
  pip uninstall "$@"
}

upgrade () {
  pip install --upgrade "$@"
}

search () {
  pip search "$@"
}

"$@"
