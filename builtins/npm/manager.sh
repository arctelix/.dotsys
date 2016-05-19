#!/bin/sh

install () {
  npm install -g $@
  return $?
}

uninstall () {
  npm uninstall -g $@
  return $?
}

upgrade () {
  install $@
  return $?
}

$@ # Required for function execution
