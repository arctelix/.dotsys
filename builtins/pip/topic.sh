#!/bin/bash

# pip/topic.sh

upgrade () {
    pip install --upgrade pip
}


freeze () {
  pip freeze
}

"$@"