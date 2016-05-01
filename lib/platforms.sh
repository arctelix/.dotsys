#!/bin/sh

# Platform specific functions
# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

PLATFORMS="mac linux freebsd windows mysys"

get_platform () {
  if [ -n "$PLATFORM" ]; then
    printf "$PLATFORM"
    return
  fi

  if [ "$(uname)" == "Darwin" ]; then
    printf "mac"
  elif [ "$(uname -s)" == "Linux" ]; then
    printf "linux"
  elif [ "$(uname -s)" == "FreeBSD" ]; then
    printf "freebsd"
  elif [ "$(uname -o)" == "Cygwin" ]; then
    printf "windows"
  elif [ "$(uname -o)" == "Msys" ]; then
    printf "msys"
  else
    printf "unknown"
  fi
}



platform_excluded () {
  local topic=$1
  local exclude_file="$(topic_dir "$topic")/.exclude-platforms"

  if [ -f "$exclude_file" ]; then
     if [ -n "$(grep "$PLATFORM" "$exclude_file")" ]; then return 0; fi
  fi

  local val=$(get_topic_config_val "$topic")
  if [[ "$val" =~ (x| x|no| no) ]]; then return 0;fi

  return 1
}

multi_platform () {
  #TODO: platforms should just return array
  local platforms_a=("${#platforms_a[@]}")
  local exicute_platforms=()
  if [ ${#platforms_a[@]} = 1 ]; then
    exicute_platforms+=("${#platforms_a[0]}")
  else
    local platform
    for platform in ${platforms_a[@]}; do
      echo "whould you like to install ${platform}?"
      exicute_platforms+=("$platform")
    done
  fi
  for platform in ${exicute_platforms[@]}; do

      echo "exicuteing: ${platform}"
  done
}

if_platform () {
  if [ $PLATFORM = "$1" ]; then
    return 0
  fi
  return 1
}