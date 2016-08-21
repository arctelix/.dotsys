#!/bin/bash

# Platform specific functions
# Author: arctelix

# https://en.wikipedia.org/wiki/Comparison_of_Linux_distributions

PLATFORMS="linux windows mac freebsd openbsd ubuntu debian archlinux cygwin msys babun"

get_platform () {

  if [ "$_cache_platform" ]; then
    printf "$_cache_platform"
    return
  fi

  local platform
  local platform_version

  platform_version="$(uname -r)"

  if [ "$(uname)" = "Darwin" ]; then
    platform="linux-mac"

  elif [ "$(uname -s)" = "FreeBSD" ]; then
    platform="linux-freebsd"

  elif [ "$(uname -s)" = "OpenBSD" ]; then
    platform="linux-openbsd"

  elif [ "$(uname -s)" = "Linux" ]; then

    # Modern linux distros
    if [ -f /etc/os-release ]; then
        . /etc/os-release

        if ! platform_supported "$ID" ; then
            platform="linux-$ID_LIKE"
            warn "Platform, $ID, is not supported. Tying similar platform $ID_LIKE."
        else
            platform="linux-$ID"
        fi

    # Some modern linux distros
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        platform="linux-$DISTRIB_ID"

    # debain based fall back
    elif [ -f /etc/debian_version ]; then
        platform="linux-debian"
        grep -q 'Ubuntu' '/etc/debian_version' && platform="linux-ubuntu"

    # redhat based fall back
    elif [ -f /etc/redhat-release ]; then
        platform="linux-redhat"
        grep -q 'CentOS' '/etc/debian_version' && platform="linux-centos"

    # Other linux distros
    else
        platform="linux-unknown"
    fi

  elif [ "$(uname -o)" = "Cygwin" ]; then
    platform="windows-cygwin"
    [ "$BABUN_HOME" ] && platform="windows-babun"

  elif [ "$(uname -o)" = "Msys" ]; then
    platform="windows-msys"

  else
    platform="unknown-unknown"
  fi

  if ! platform_supported "$platform" ; then
    error "$platform, is not currently supported. Please submit this issue"
    exit
  fi

  platform="$(echo "$platform" | tr '[:upper:]' '[:lower:]')"

  _cache_platform="$platform"

  echo "$platform"
}

platform_supported () {

    case "$1" in
    *mac )       platform="$1";;
    *cygwin )    platform="$1";;
    *msys )      platform="$1";;
    *centos )    platform="$1";;
    *redhat )    platform="$1";;
    *archlinux ) platform="$1";;
    *ubuntu )    platform="$1";;
    *debian )    platform="$1";;
    *freebsd )   platform="$1";;
    *openbsd )   platform="$1";;
    *openbsd )   platform="$1";;
    esac

    [ "$platform" ]
}

platform_user_bin () {

  local bin_path="/usr/local/bin"
  local missing_var
  local example
  local platform="${1:-$(get_platform)}"

  debug "-- platform_user_bin: $platform"

  if [ -d "$bin_path" ] || [ -d "$_cache_bin_path" ];then
    debug "   user bin path ok: $bin_path"
    echo "$bin_path"
    return 0
  fi

  case "$platform" in

      *cygwin | *babun )

          if ! [ "$CYGWIN_HOME" ]; then
              if [ "$platform" = "windows-babun" ]; then
                CYGWIN_HOME="/cygdrive/c/.babun/cygwin/"
              else
                CYGWIN_HOME="/cygdrive/c/cygwin"
              fi
              debug "set CYGWIN_HOME=$CYGWIN_HOME"
          fi

          bin_path="$CYGWIN_HOME$bin_path"

          if ! [ -d "$bin_path" ]; then
              missing_var="CYGWIN_HOME"
              example="/cygdrive/c/cygwin"
          else
              bin_path="$(printf "%s" "$(cygpath --unix "$bin_path")")"
          fi
      ;;
      *msys )

          if ! [ "$MSYS_HOME" ]; then
              MSYS_HOME="/c/msys/1.0"
              bin_path="$MSYS_HOME/$bin_path"
          fi

          bin_path="$MSYS_HOME$bin_path"

          #TODO: Need solution to cygpath for msys
          if ! [ -d "$bin_path" ]; then
              missing_var="MSYS_HOME"
              example="/c/msys/1.0"
          fi

      ;;
  esac

  if [ -d $bin_path ];then
    debug "   user bin path ok: $bin_path"
    _cache_bin_path="$bin_path"
    echo "$bin_path"
    return 0
  fi


  error "The platform_user_bin directory" "$bin_path" "does not exist for" "$platform"

  if [ "$missing_var" ]; then

    msg_help "You need to set the environment variable $missing_var to the
            \rabsolute path of your system root where usr/local/bin resides.
            \rfor example: $missing_var=$example"

  fi

  return 1
}

# Gets full path to users home directory based on platform
platform_user_home () {

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
      fail "Cannot determine home directories for" "$( printf "%b$platform" "$hc_topic")"
      ;;
  esac


  echo "$home"
}

platform_required_topics () {
    local platform="$(get_platform)"
    case $platform in
    windows-cygwin ) echo "cygwin";;
    windows-msys ) echo "msys";;
    windows-babun ) echo "babun";;
    esac

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