#!/bin/bash

# pip/manager.sh

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
