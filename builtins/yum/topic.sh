#!/bin/bash

freeze () {
    yum list installed "$@"
}

"$@"