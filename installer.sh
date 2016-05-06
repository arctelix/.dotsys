#!/bin/sh

if ! [ "$DOTSYS_LIBRARY" ];then
    if [ ! -f "$0" ];then
        DOTSYS_REPOSITORY="$(dirname "$BASH_SOURCE")"
    else
        DOTSYS_REPOSITORY="$(dirname "$0")"
    fi
    DOTSYS_LIBRARY="$DOTSYS_REPOSITORY/lib"
fi

echo "- install DOTSYS_LIBRARY: $DOTSYS_REPOSITORY"

. "$DOTSYS_LIBRARY/main.sh"


dotsys_installer "${1:-install}"

