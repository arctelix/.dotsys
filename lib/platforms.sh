#!/bin/sh

# Platform specific functions
# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

PLATFORMS="mac linux freebsd windows mysys"

#TODO: implement tests for new platform platform names cygwin* *windows *bsd

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
  elif [ "$(uname -s)" == "OpenBSD" ]; then
    printf "openbsd"
  elif [ "$(uname -o)" == "Cygwin" ]; then
    printf "cygwin-windows"
  elif [ "$(uname -o)" == "Msys" ]; then
    printf "msys-windows"
  else
    printf "unknown"
  fi
}


platform_user_bin () {

  if [ -n "$PLATFORM_USER_BIN" ]; then
    printf "$PLATFORM_USER_BIN"
    return
  fi

  local path="/usr/local/bin"
  local missing_var

  case "$(get_platform)" in
      mac|linux|*bsd )
          echo "$path"
          return
      ;;
      cygwin* ) path="$CYGWIN_HOME/$path"

          if ! [ -d "$path" ]; then
              missing_var="CYGWIN_HOME"
          else
              echo "$(printf "%s" "$(cygpath --unix "$CYGWIN_HOME")")"
              return
          fi
      ;;
      msys* ) path="$MSYS_HOME/$path"

          if ! [ "$MSYS_HOME" ]; then
              MSYS_HOME="/c/msys/1.0"
              path="$MSYS_HOME/$path"
          fi
          #TODO: Need solution to cygpath for msys
          if ! [ -d "$path" ]; then
              missing_var="CYGWIN_HOME"
          else
              echo "$MSYS_HOME"
              return
          fi

      ;;
  esac

  error "$(printf "Cannot determine the $path directly for platform %b%s%b" \
                   green "$platform" $rc)"

  if [ "$missing_var" ]; then

    msg_help "You need to set the environment variable $missing_var to the absolute
            \rpath of your system root where usr/local/bin resides.
            \rex:/c/msys/1.0 or /c/cygwin"

  fi

  exit
}

# Gets full path to users home directory based on platform
user_home_dir () {
  local platform="${1:-$PLATFORM}"

  if [ "$HOME" ]; then
      echo "$HOME"
      return
  fi

  case "$platform" in
    cygwin* )
      echo "$(printf "%s" "$(cygpath --unix $USERPROFILE)")"
      ;;
    * )
      fail "$(printf "Cannot determine home directories for platform %b%s%b" $green "$platform" $rc)"
      ;;
  esac
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