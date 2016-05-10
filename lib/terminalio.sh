#!/bin/sh

# Screen input & output
# Author: arctelix

# COLORS

red="\e[0;31m"
dark_red="\e[01;31m"

green="\e[0;32m"
dark_green="\e[01;32m"

yellow="\e[0;33m"
dark_yellow="\e[01;33m"

blue="\e[0;34m"
dark_blue="\e[01;34m"

magenta="\e[0;35m"
dark_magenta="\e[01;35m"

cyan="\e[0;36m"
dark_cyan="\e[01;36m"

gray="\e[0;37m"
dark_gray="\e[0;90m"

rc="\e[0m" #reset color

clear_line="\r\e[K"
clear_line_above="\e[1A\r\e[K"

spacer="\r\e[K        " # indent from screen edge
indent="        " # indent from current position

# OUTPUT

# feedback

info () {
  printf   "\r%b[%b INFO %b] %b\n" $clear_line $dark_blue $rc "$1"
}

warn () {
  printf   "\r%b[%b WARN %b] %b\n" $clear_line $dark_yellow $rc "$1"
}

user () {
  printf   "\r%b[%b  ?   %b] %b" $clear_line $dark_yellow $rc "$1"
}

success () {
  printf "\r%b[%b  OK  %b] %b\n" $clear_line $dark_green $rc "$1"
}


fail () {
  printf  "\r%b[%b FAIL %b] %b\n" $clear_line $dark_red $rc "$1"
  debug_log_msg "fail" "$1"
}

task() {
  printf  "\r%b[%b TASK %b] %b$1%b %b\n" $clear_line $dark_cyan $rc $cyan $rc "$2"
}

# messages

msg () {
  printf  "\r%b%b$1%b\n" $clear_line $yellow $rc

}

msg_help () {
  printf  "\r%b$1%b\n" $dark_gray $rc

}

error () {
  printf  "\r\n%b%bERROR:  %b ${1}%b\n\n" $clear_line $dark_red $red $rc
  debug_log_msg "error" "$1"

}

pass (){
    return $?
}

freeze_msg () {
    local task="$1"
    local desc="$2"
    local items="$3"

    printf  "$spacer %b$task%b : $desc\n" $green $rc

    if ! [ "$items" ]; then return;fi

    while IFS=$'\n' read -r item; do
        printf  "$spacer - %b$item%b\n" $green $rc
    done <<< "$items"
}

debug_log_msg () {
    local status="$1"
    local item="$2"
    printf "$status: $item \n" >> "$DOTSYS_REPOSITORY/debug.log"
}

success_or_fail () {
    func_or_func_msg success fail $1 "$2" "${3:-$?}"
}

success_or_error () {
    func_or_func_msg success error $1 "$2" "${3:-$?}"
}

success_or_none () {
    func_or_func_msg success pass $1 "$2" "${3:-$?}"
}

func_or_func_msg () {
    local zero_func="$1"
    local other_func="$2"
    local status="$3"
    local action="$4"
    local message="$5"
    shift; shift; shift; shift; shift

    if [ $status -eq 0 ]; then
        if [ "$action" ]; then
            action="${action%ed}"
            action="$(cap_first "${action%e}ed")"
            $zero_func "$action $message"
        else
            $zero_func "$message"
        fi
    else
        if [ "$action" ]; then
            $other_func "Failed to $action $message"
        else
            $other_func "Failed to $message"
        fi
        # all additional params get executed here
        if [ $@ ]; then $@; fi
        exit
    fi
    return $status
}


# adds indent to all but first line
indent_lines () {
  local first
  while read -r line; do
    if ! [ "$first" ];then
        first="true"
        printf "$line\n"
    else
        printf "$indent $line\n"
    fi
  done <<< "$1"
}


# invalid option
msg_invalid_input (){
    printf "$clear_line"
    printf "$celar_line_above"
    clear_lines "$1"
    user "$1"
}

# debug debug
debug () {
    if [ "$DEBUG" = true ]; then
        printf "%b$1 %b\n" $dark_gray $rc
    fi
}

not_implimented () {
    if [ "$DEBUG" = true ]; then
        printf "$spacer NOT IMPLEMENTED: %b$1 %b\n" $gray $rc
    fi
}

cap_first () {
    echo `echo ${1:0:1} | tr  '[a-z]' '[A-Z]'`${1:1}
}

clear_lines () {
    printf "$clear_line"
    if ! [ "$1" ];then return;fi
    local lines=$(printf "$1" | wc -l)
    lines=$lines+1 #clears all lines
    local sub=${2:-0} # add (+#) or subtract (-#) lines to clear
    local c
    for (( c=1; c<=$lines+$sub; c++ )); do printf "$clear_line_above"; done
}

get_user_input () {

    local usage="get_user_input [<action>]"
    local usage_full="

    -o | --options )    alternate options line
                        or 'none' for no options
    -e | --extra)       extra option
    -h | --hint)        option line hint for no invalid input
    -c | --clear )      Number + extra/ - less lines to lear [0]
    -t | --true )       Text to print for 0 value
                        set to 'none' for required variable input
    -f | --false        Text to print for 1 value
                        or 'none' require input.
    -i | --invalid      Text to print on invalid selection
                        or 'none' noting is invalid
    -d | --default      Default value on enter key
    -r | --required     Make confirmation required
         --help         Text to print for help
      "

    local question=
    local true=
    local false=
    local help="no help available"
    local default
    local options
    local clear="false"
    local invalid="invalid"
    local confirmed="$TOPIC_CONFIRMED"
    local hint="\b"
    local extra=()


    while [[ $# > 0 ]]; do
    case "$1" in
      -o | --options )  options=" $2";shift;;
      -e | --extra)     extra+=("$2");shift;;
      -h | --hint)      hint="$2";shift;;
      -c | --clear )    clear="$2";shift;;
      -t | --true )     true="$2";shift;;
      -f | --false )    false="$2";shift;;
      -i | --invalid )  invalid="$2";shift;;
      -d | --default )  default="$2";shift ;;
      -r | --required ) confirmed= ;;
           --help )     help="$2";shift ;;
      * ) uncaught_case "$1" "question" "true" "false" "help" ;;
    esac
    shift
    done

    true="${true:-yes}"
    false="${false:-no}"

    debug "-- get_user_input: TOPIC_CONFIRMED=$TOPIC_CONFIRMED sets confirm=$confirmed "

    if [ "$options" = "none" ]; then
        true="none"
        false="none"
        confirmed=""
    # just offer false option everything else is true
    elif [ "$true" = "none" ]; then
        options="$(printf "(%b${false:0:1}%b)%b${false:1}%b" $yellow $rc $yellow $rc)"
        confirmed=""
        invalid="none"

    # just offer true option everything is true
    elif [ "$false" = "none" ]; then
        options="$(printf "(%b${true:0:1}%b)%b${true:1}%b" $green $rc $green $rc)"
        confirmed=""
        invalid="none"

    # use default options
    else
        options="$(printf "(%b${true:0:1}%b)%b${true:1}%b (%b${false:0:1}%b)%b${false:1}%b" \
                        $green $rc $green $rc $yellow $rc $yellow $rc)"
    fi

    # put options on new line
    if [ "$hint" ] || [ "${extra[0]}" ]; then
       options="\n$spacer $options"
    fi

    # format extra options
    local opt
    local extra_regex
    for opt in "${extra[@]}"; do
        if [ "$extra_regex" ]; then extra_regex="${extra_regex}|";fi
        #TODO the extra_regex does not pickup on pipes
        extra_regex="${extra_regex}${opt}|${opt:0:1}"
        opt="$(printf "(%b${opt:0:1}%b)%b${opt:1}%b" $yellow $rc $yellow $rc)"
        options="$options $opt"
    done

    extra_regex="${extra_regex:-All the things that make architects go mad!}"
    debug "extra_regex=$extra_regex"


    default="${default:-$true}"
    question=$(printf "$question $options $hint [%b${default}%b]" $dark_gray $rc)

    user "${question} : "

    debug "-- get_user_input: confirm=$confirmed invalid=$invalid TOPIC_CONFIRMED=$TOPIC_CONFIRMED"

    if ! [ "$confirmed" ]; then
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
                ${extra_regex} )
                    state=1
                    break
                    ;;
                "")
                    # blank value ok
                    if [ "$true" = "none" ]; then
                        status=1
                        user_input=
                        break
                    fi
                    # blank value = default choice
                    user_input="${default}"
                    [ "$user_input" = "$true" ]
                    state=$?
                    break
                    ;;
                * )
                    # any input is ok
                    if [ "$invalid" = "none" ]; then
                        status=0
                        break
                    fi
                    # use invalid message
                    msg_invalid_input "$question > $invalid : "
                    ;;
            esac
        done
    else
        user_input="$default"
        printf "\n\r"
    fi

    if [ "$clear" != "false" ]; then
        clear_lines "$question" ${clear:-0}
    fi

    return $state
}

confirm_task () {

  local usage="confirm_task <action> <topic> <limits>..."

  local action="${1-$action}"
  local prefix="${2:-\b}"
  local topic="${3:-$topic}"
  local extra_lines=()
  shift; shift; shift
  local confirmed=

  local CONFIRMED_VAR="TOPIC_CONFIRMED"

  while [[ $# > 0 ]]; do
    case "$1" in
      -c | --confirmed )        confirmed="true";   shift ;;# alternate options line
      -v | --confvar )          CONFIRMED_VAR="$2"; shift ;;# alternate options line
      * ) extra_lines+=("$1") ;;
    esac
    shift
  done

  local line
  local lines=""
  for line in "${extra_lines[@]}"; do
    lines+="\n$spacer $line"
  done

  debug "CONFIRMED_VAR=${CONFIRMED_VAR}"
  debug "CONFIRMED_VAR value=${!CONFIRMED_VAR}"

  if ! [ "${!CONFIRMED_VAR}" ] && ! [ "$confirmed" ] && [ "$topic" ]; then

      local text="$(printf "Would you like to %b%s%b %s %b%s%b %s?
         $spacer (%by%b)es, (%bY%b)es all, (%bn%b)o, (%bN%b)o all [%byes%b] : " \
         $green "$action" $rc "$prefix" $green "$topic" $rc "$lines" \
         $yellow $rc \
         $yellow $rc \
         $yellow $rc \
         $yellow $rc \
         $dark_gray $rc)"

      user "$text"

      while true; do
          # Read from tty, needed because we read in outer loop.
          read user_input < /dev/tty

          case "$user_input" in
            y )
              confirmed="true"
              break
              ;;
            n )
              confirmed="false"
              break
              ;;
            Y )
              eval "${CONFIRMED_VAR}=true"
              break
              ;;
            N )
              eval "${CONFIRMED_VAR}=false"
              break
              ;;
            "" )
              confirmed="true"
              break
              ;;
            * )
              msg_invalid_input "$text invalid : "
              ;;
          esac
      done
      clear_lines "$text"

  fi

  debug "CONFIRMED_VAR value=${!CONFIRMED_VAR}"

  confirmed="${confirmed:-${!CONFIRMED_VAR}}"

  if [ "$confirmed" != "false" ]; then
    task "$(printf "%sing %s %s %b%s%b %s" $(cap_first "${action%e}") "$DRY_RUN" "$prefix" $green "$topic" $cyan "$extra_lines")"
    return 0
  else
    task "$(printf "You skipped %s for %s %b%s%b %s" "$action" "$prefix" $green "$topic" $cyan "$extra_lines")"
    return 1
  fi
}

# USAGE & HELP SYSTEM

# Shows local usage and usage_full text and exits script
show_usage () {

  while [[ $# > 0 ]]; do
    case "$1" in
      -f | --full   ) state="full" ;;
      * ) error "Invalid option: $1";;
    esac
    shift
  done

  printf "$usage\n"

  if [ "$state" = "full" ]; then
    printf "$usage_full\n"
  else
    printf "Use <command> -h or --help for more.\n"
  fi
  exit
}

# Display invalid option message and exit
invalid_option () {
    error "invalid option: $1"
    show_usage
    exit
}

invalid_limit () {
    error "invalid limit: $1"
    show_usage
    exit
}

# Checks for a help param and shows help
# ex: check_for_help "$1"
check_for_help () {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then show_usage -f; fi
}

# Confirms provided param list is longer then a specified length.
# also checks for a help request
# Shows error with basic usage on fail
# ex: required_params 2 $@
required_params () {
  local required=$1
  shift
  check_for_help "$1"
  if ! (( $# >= $required )); then
    error "Requires ${#required} parameters and $# supplied."
    show_usage
  fi

}

# Confirms a list of var names are set
required_vars () {
  local missing=
  local recieved=
  local p
  for p in $@; do
    if ! [ "${!p}" ]; then
      missing+="<${p}> "
    else
      recieved+="<${p}> "
    fi
  done
  if [ "$missing" ]; then
    error "Missing or incorrect parameters $missing
    recieved: $recieved"
    show_usage
  fi
}

# A short cut method handle uncaught case
# Sets a specified list of variable names to the current param value.
# Catches invalid options (unspecified in case and prefixed with -).
# Catches too many params provided
# Displays error message and basic usage on fail
# ex: uncaught_case "$1" "var_name" "var_name"
uncaught_case (){
 local uc_c_val="$1"
 shift
 local set_var
 local uc_p_names="$@"
 local us_p_name
 for us_p_name in $uc_p_names; do
    if [[ "$uc_c_val" == "-"* ]]; then
        printf "Invalid parameter '$uc_c_val'"
        show_usage
    fi
    # if the supplied variable name is not set
    if [ -z "${!us_p_name}" ]; then
      local eval_exp="${us_p_name}=\"$uc_c_val\""
      eval "$eval_exp"
      set_var="$us_p_name"
      break
    fi
 done

 if [ -z "$set_var" ] && [ "$uc_c_val" ]; then
   local uc_c_vals=""
   for us_p_name in $uc_p_names;do
        uc_c_vals+="${us_p_name}=${!us_p_name}\n"
   done


   error "Too many params:
   \r${uc_c_vals}\rhave been set and got value: $uc_c_val"
   show_usage
 fi
}
