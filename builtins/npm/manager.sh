#!/bin/bash

# npm/manager.sh

install () {
  dsudo npm install -g "$@"
}

uninstall () {
  dsudo npm uninstall -g "$@"
}

upgrade () {
  dsudo npm update -g "$@"
}

search () {
  dsudo npm search "$@"
}

"$@"
