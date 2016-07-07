#!/bin/sh

install () {
  npm install -g $@
}

uninstall () {
  npm uninstall -g $@
}

upgrade () {
  npm update -g $@
}

freeze () {
  npm ls -g $@
}

"$@" # Required for function execution
