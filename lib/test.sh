#!/bin/sh


#read() { builtin read "$@" 2>/dev/tty; }
echo "this is a line of output from test 1"
echo "this is a line of output from test 2"
echo "this is a line of output from test 3"
read -p "enter your name for from test: " user_input
echo
echo "$user_input is your name"
#unset -f read


