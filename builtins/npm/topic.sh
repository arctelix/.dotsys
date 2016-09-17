#!/bin/bash

# npm/manager.sh

install () {
#   # When installing node on windows 'npm' may not be on path yet so lets find it
#   find_windows_cmd npm
    return 0
}

upgrade () {
    npm install npm -g
}


freeze () {
  npm ls -g $@
}

"$@"