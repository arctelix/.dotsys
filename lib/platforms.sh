#!/bin/sh

# Platform specific functions
# Author: arctelix

PLATFORMS="linux windows mac freebsd openbsd ubuntu debian archlinux cygwin msys babun"

get_platform () {

  if [ -n "$PLATFORM" ]; then
    printf "$PLATFORM"
    return
  fi

  local platform

  if [ "$(uname)" == "Darwin" ]; then
    platform="linux-mac"
  elif [ "$(uname -s)" = "FreeBSD" ]; then
    platform="linux-freebsd"
  elif [ "$(uname -s)" == "OpenBSD" ]; then
    platform="linux-openbsd"
  elif [ "$(uname -s)" == "Linux" ]; then
    platform="linux"
  elif [ "$(uname -o)" == "Cygwin" ]; then
    platform="windows-cygwin"
    babun >/dev/null 2>&1 && platform="windows-babun"
  elif [ "$(uname -o)" == "Msys" ]; then
    platform="windows-msys"
  else
    platform="unknown"
  fi

  echo "$platform"
}


platform_user_bin () {

  if [ ! "$1" ] && [ -n "$PLATFORM_USER_BIN" ]; then
    echo "$PLATFORM_USER_BIN"
    return
  fi

  local bin_path="/usr/local/bin"
  local missing_var
  local platform="${1:-$(get_platform)}"

  case "$platform" in
      linux* )
          echo "$bin_path"
          return
      ;;
      *cygwin | *babun ) bin_path="$CYGWIN_HOME/$bin_path"

          if ! [ -d "$bin_path" ]; then
              missing_var="CYGWIN_HOME"
          else
              echo "$(printf "%s" "$(cygpath --unix "$bin_path")")"
              return
          fi
      ;;
      *msys ) bin_path="$MSYS_HOME/$bin_path"

          if ! [ "$MSYS_HOME" ]; then
              MSYS_HOME="/c/msys/1.0"
              bin_path="$MSYS_HOME/$bin_path"
          fi
          #TODO: Need solution to cygpath for msys
          if ! [ -d "$bin_path" ]; then
              missing_var="MSYS_HOME"
          else
              echo "$MSYS_HOME"
              return
          fi

      ;;
  esac

  error "The platform_user_bin directory" "$bin_path" "does not exist for" "$platform"

  if [ "$missing_var" ]; then

    msg_help "You need to set the environment variable $missing_var to the absolute
            \rpath of your system root where usr/local/bin resides.
            \rex:/c/msys/1.0 or /c/cygwin"

  fi

  exit
}

# Gets full path to users home directory based on platform
platform_user_home () {

  if [ ! "$1" ] && [ "$PLATFORM_USER_HOME" ]; then
      echo "$PLATFORM_USER_HOME"
      return
  fi

  if [ "$HOME" ]; then
      echo "$HOME"
      return
  fi

  local home
  local platform="${1:-$(get_platform)}"

  case "$platform" in
    *cygwin )
      home="$(printf "%s" "$(cygpath --unix $USERPROFILE)")"
      ;;
    *msys )
      home="$(printf "%s" "$($USERPROFILE)")"
      ;;
    * )
      fail "Cannot determine home directories for" "$( printf "%b$platform" $hc_topic)"
      ;;
  esac


  echo "$home"
}

topic_excluded () {
  local topic=$1
  local platform="${1:-$(get_platform)}"
  local exclude_file="$(topic_dir "$topic")/.exclude-platforms"

  # generic platform linux.*
  local generic="$(generic_platform "$platform")"
  # specific platform *.mac
  local specific="$(specific_platform "$platform")"

  if [ -f "$exclude_file" ]; then
     if [ -n "$(grep "$specific" "$exclude_file")" ]; then return 0; fi
     if [ -n "$(grep "$generic" "$exclude_file")" ]; then return 0; fi
  fi

  # topic val
  local val=$(get_topic_config_val "$topic")

  # topic specific platform val
  if ! [ "$val" ]; then val="$(get_topic_config_val "$topic" "$specific")"; fi
  # topic generic platform val
  if ! [ "$val" ]; then val="$(get_topic_config_val "$topic" "$generic")"; fi


  if [[ "$val" =~ (x| x|no| no) ]]; then return 0;fi

  return 1
}

# SPECIFIC PATFORM SHOULD ALWAYS SUPERSEDE GENERIC
# ie: mac value should supered linux
# ie: cygn value should supered windows
specific_platform () {
    local platform="${1:-$(get_platform)}"
    echo "${platform#*-}"
}
generic_platform () {
    local platform="${1:-$(get_platform)}"
    echo "${platform%-*}"
}

is_platform () {
  local platform="${1:-$(get_platform)}"
  if [ "$(specific_platform "$platform")" = "$platform" ]; then
    return 0
  elif [ "$(generic_platform "$platform")" = "$platform" ]; then
    return 0
  fi

  return 1
}