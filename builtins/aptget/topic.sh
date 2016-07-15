#!/bin/bash

# NEVER INSTALL OR UNINSTALL APT-GET!

upgrade () {
  # would upgrade packages and we don't want that here
  # dsudo apt-get upgrade
  return 0
}

update () {
  dsudo apt-get update
}

freeze () {
  dpkg-query -f '${binary:Package}\n' -W
}

"$@"

