#!/bin/bash

# pip/topic.sh

export PIP_REQUIRE_VIRTUALENV=""

upgrade () {
    pip install --upgrade pip
}


freeze () {
  pip freeze
}

"$@"