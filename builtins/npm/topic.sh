#!/bin/bash

install () {
#    # When installing node on windows 'npm' may not be on path yet so lets find it
#    find_windows_cmd npm
#    # updating npm on install seems a bit excessive..
#    npm install npm -g
    return 0
}

uninstall () {
    return 0
}

upgrade () {
    npm install npm -g
}

update () {
    npm install npm -g
}

freeze () {
  npm ls -g $@
}

"$@"