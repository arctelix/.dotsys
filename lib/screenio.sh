#!/bin/sh

# Screen input & output
# Author: arctelix

# COLORS

red="\e[0;31m"
light_red="\e[01;31m"
green="\e[0;32m"
light_green="\e[01;32m"
yellow="\e[0;33m"
light_yellow="\e[01;33m"
blue="\e[0;34m"
light_blue="\e[01;34m"
gray="\e[0;37m"
dark_gray="\e[0;90m"
rc="\e[0m"
clear_line="\r\e[K"
clear_line_above="\e[1A\r\e[K"
spacer="\r\e[K        "
save_cp="\e[s"
restore_cp="\e[u"

# OUTPUT

info () {
  printf   "\r%b[%b INFO %b] %b\n" $clear_line $light_blue $rc "$1"
}

warn () {
  printf   "\r%b[%b WARN %b] %b\n" $clear_line $light_yellow $rc "$1"
}

user () {
  printf   "\r%b[%b  ?   %b] %b" $clear_line $light_yellow $rc "$1"
}

success () {
  printf "\r%b[%b  OK  %b] %b\n" $clear_line $light_green $rc "$1"
}


fail () {
  printf  "\r%b[%b FAIL %b] %b\n" $clear_line $light_red $rc "$1"
  #exit 1
}

error () {
  printf  "\r\n%b%bERROR:%b ${1}%b\n\n" $clear_line $light_red $red $rc

}

msg () {
  printf  "\r%b%b${1}%b\n" $clear_line $yellow $rc

}

msg_help () {
  printf  "\r%b$1. Use %babort%b to skip.\n%b" $dark_gray $blue $dark_gray $rc

}

cap_first () {
  echo `echo ${1:0:1} | tr  '[a-z]' '[A-Z]'`${1:1}
}


task() {
  printf  "\r%b[%b TASK %b] %b$1%b %b\n" $clear_line $light_blue $rc $blue $rc "$2"
}

msg_invalid (){
  printf "$clear_line"
  printf "$celar_line_above"
  clear_lines "$1"
  user "$1"
}

clear_lines () {
      printf "$clear_line"
      local lines=$(printf "$1" | wc -l)
      lines=$lines+1 #clears all lines
      local sub=${2:-0} # add (+#) or subtract (-#) lines to clear
      for (( c=1; c<=$lines+$sub; c++ )); do printf "$clear_line_above"; done
}

get_user_input () {
    local question=
    local true="yes"
    local false="no"
    local help=
    local clear="false"
    local invalid="invalid"

    local options="$(printf " (%b${true:0:1})${true:1}%b (%b${false:0:1})${false:1}%b" $yellow $rc $yellow $rc)"

    while [[ $# > 0 ]]; do
    case "$1" in
      -o | --o )        options=" $2"; shift ;;# alternate options line
      -c | --clear )    clear="$2"; shift ;;  # Number of lines to leave [0]
      -t | --true )     true="$2"; shift ;;   # Text to print for 0 value
      -f | --false )    false="$2"; shift ;;  # Text to print for 1 value
      -h | --help )     help="$2"; shift ;;   # Text to print for help
      -i | --invalid )  invlaid="$2"; shift ;;# Text to print invalid selection
      * ) uncaught_case "$1" "question" "true" "false" "help" ;;
    esac
    shift
    done

    question=$(printf "$question ?$options")

    user "${question} : "

    local state=0
    while true; do
        read user_input < /dev/tty
        #user_input="$user_input"
        case "$user_input" in
            ${true}|${true:0:1})
                state=0
                user_input="${true}"
                break
                ;;
            ${false}|${false:0:1}|abort)
                state=1
                user_input="${false}"
                break
                ;;
            help )
                msg_help "$(printf "$help")"
                ;;
            * )
                if [ "$invlaid" = "false" ]; then break;fi
                msg_invalid "$question > $invalid : "
                ;;
        esac
    done

    if [ "$clear" != "false" ]; then
        clear_lines "$question" ${clear:-0}
    fi

    return $state
}

confirm_task () {

  local action="${1-$action}"
  local topic="${2:-$topic}"
  local limits="${3}"

  local confirmed=

  if ! [ "$P_STATE" ] && [ "$topic" ]; then

      local text="$(printf "Would you like to %b%s %s%b%s?
         $spacer (%by%b)es, (%bY%b)es all, (%bs%b)kip, (%bS%b)kip all : %b" \
         $green "$action" "$topic" $rc " $limits" \
         $yellow $rc \
         $yellow $rc \
         $yellow $rc \
         $yellow $rc $save_cp)"

      user "$text"

      while true; do
          # Read from tty, needed because we read in outer loop.
          read user_input < /dev/tty

          case "$user_input" in
            y )
              confirmed="true"
              break
              ;;
            s )
              confirmed="false"
              break
              ;;
            Y )
              P_STATE="true"
              break
              ;;
            S )
              P_STATE="false"
              break
              ;;
            * )
              msg_invalid "$text invalid : "
              ;;
          esac
      done
      clear_lines "$text"

  fi

  confirmed="${confirmed:-$P_STATE}"

  if [ "$confirmed" = "true" ]; then
    task "$(printf "%b%sing %s%b%s" $green $(cap_first "$action") "$topic" $rc " $limits")"
    return 0
  else
    task "$(printf "%s %s (skipped by user)%b%s" $(cap_first "$action") "$topic" $rc " $limits")"
    return 1
  fi
}