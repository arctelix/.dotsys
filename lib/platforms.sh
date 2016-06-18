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

  PLATFORM="$platform"
  echo "$platform"
}


platform_user_bin () {

  if [ -n "$PLATFORM_USER_BIN" ]; then
    printf "$PLATFORM_USER_BIN"
    return
  fi

  local bin_path="/usr/local/bin"
  local missing_var

  case "$(get_platform)" in
      linux* )
          echo "$bin_path"
          return
      ;;
      *cygwin ) bin_path="$CYGWIN_HOME/$bin_path"

          if ! [ -d "$bin_path" ]; then
              missing_var="CYGWIN_HOME"
          else
              echo "$(printf "%s" "$(cygpath --unix "$CYGWIN_HOME")")"
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

  error "$(printf "Cannot determine the $bin_path directly for platform %b%s%b" \
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
    *cygwin )
      HOME="$(printf "%s" "$(cygpath --unix $USERPROFILE)")"
      ;;
    *msys )
      HOME="$(printf "%s" "$($USERPROFILE)")"
      ;;
    * )
      fail "Cannot determine home directories for" "$( printf "%b$platform" $thc)"
      ;;
  esac

  echo "$HOME"
}


topic_excluded () {
  local topic=$1
  local platform="${2:-$PLATFORM}"
  local exclude_file="$(topic_dir "$topic")/.exclude-platforms"

  # generic platform linux.*
  local generic="$(generic_platform)"
  # specific platform *.mac
  local specific="$(specific_platform)"

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
    local platform="${1:-$PLATFORM}"
    echo "${platform#*-}"
}
generic_platform () {
    local platform="${1:-$PLATFORM}"
    echo "${platform%-*}"
}

if_platform () {
  local platform="${1:-$PLATFORM}"
  if [ "$(specific_platform "$platform")" = "$platform" ]; then
    return 0
  elif [ "$(generic_platform "$platform")" = "$platform" ]; then
    return 0
  fi

  return 1
}

get_platform 2>&1 >/dev/null