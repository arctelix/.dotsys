#!/bin/bash

install () {
  dsudo npm install -g "$@"
}

uninstall () {
  dsudo npm uninstall -g "$@"
}

upgrade () {
  dsudo npm update -g "$@"
}

"$@"
