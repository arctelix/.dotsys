#!/bin/bash

# USer input
# Author: arctelix

get_user_input () {

    local usage="get_user_input [<action>]"
    local usage_full="

    -o | --options )    alternate options line
                        or 'omit' for no options
    -e | --extra)       extra option
    -h | --hint)        optional hint line for no invalid input
    -c | --clear )      Number + extra/ - less lines to lear [0]
    -t | --true )       Text to print for 0 value
                        set to 'omit' for required variable input
    -f | --false        Text to print for 1 value
                        or 'omit' require input.
    -i | --invalid      Text to print on invalid selection
                        or 'omit' noting is invalid
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
    local true_all
    local false_all

    local hint=""
    local extra=()
    # default TOPIC_CONFIRMED allows bypass of yes no questions pertaining to topic
    # non yes/no questions should be --required or there could be problems!
    local CONFIRMED_VAR=
    local required


    while [[ $# > 0 ]]; do
    case "$1" in
      -o | --options )  options="$2";shift;;
      -e | --extra)     extra+=("$2");shift;;
      -h | --hint)      hint="$2";shift;;
      -c | --clear )    clear="$2";shift;;
      -t | --true )     true="$2";shift;;
      -f | --false )    false="$2";shift;;
      -i | --invalid )  invalid="$2";shift;;
      -d | --default )  default="$2";shift ;;
      -r | --required ) required="true" ;;
      -v | --confvar )  CONFIRMED_VAR="$2"; shift ;;# alternate options line
           --help )     help="$2";shift ;;
      * ) uncaught_case "$1" "question" "true" "false" "help" ;;
    esac
    shift
    done

    local confirmed="${!CONFIRMED_VAR}"
    if [ "$required" ]; then confirmed=; fi

    true="${true:-yes}"
    false="${false:-no}"

    # Add ALL options when confvar is supplied
    if [ "$CONFIRMED_VAR" ]; then
        true_all="$(cap_first "$true-all")"
        false_all="$(cap_first "$false-all")"
    fi

    debug "   -- get_user_input: $question"
    debug "   -- get_user_input: CONFIRMED_VAR($CONFIRMED_VAR)=${!CONFIRMED_VAR} sets confirm=$confirmed "

    if [ "$options" = "omit" ]; then
        options="\b"
        true="omit"
        false="omit"
    elif [ "$options" ]; then
        true="omit"
        false="omit"
    fi

    debug "      get_user_input: o:$options t:$true f:$false e:$extra d:$default"

    # add true
    if [ "$true" != "omit" ]; then
        options="$(printf "%b(%b${true:0:1}%b)%b${true:1}%b " \
                            "$options" $green $rc $green $rc)"
        if [ "$true_all" ]; then
            options="$(printf "%b(%b${true_all:0:1}%b)%b${true_all:1}%b " \
                            "$options" $green $rc $green $rc )"
        fi
    else
        true=
    fi

    # add false
    if [ "$false" != "omit" ]; then
        options="$(printf "%b(%b${false:0:1}%b)%b${false:1}%b " \
                            "$options" $yellow $rc $yellow $rc)"
        if [ "$false_all" ]; then
            options="$(printf "%b(%b${false_all:0:1}%b)%b${false_all:1}%b " \
                            "$options" $yellow $rc $yellow $rc)"
        fi
    else
        false=
    fi

    # put options on new line
    if [ "$hint" ] || [ "${extra[0]}" ] || [ "$CONFIRMED_VAR" ]; then
       options="\n$spacer $options"
    fi

    # format hint
    if [ "$hint" ]; then
       hint="$hint "
    fi

    # format extra options
    local opt
    local extra_regex
    for opt in "${extra[@]}"; do
        if [ "$extra_regex" ]; then extra_regex="${extra_regex},";fi
        extra_regex="${extra_regex}${opt},${opt:0:1}"
        opt="$(printf "(%b${opt:0:1}%b)%b${opt:1}%b" $yellow $rc $yellow $rc)"
        options="$options $opt"
    done

    debug "      get_user_input: extra_regex=$extra_regex"
    debug "      get_user_input: confirm=$confirmed invalid=$invalid"

    # Allow any response if no options
    if ! [ "$options" ] || [ "$options" = "\b" ]; then
        debug "      get_user_input: no options so any input ok"
        invalid=""
    fi

    # Get user input
    default="${default:-$true}"
    question="$(printf "$question $options ${hint}[%b${default}%b]" $c_default $rc)"

    user "${question}: "

    local state
    if ! [ "$confirmed" ]; then

        while true; do
            read user_input < /dev/tty

            user_input="${user_input:-$default}"

            debug "   user_input=$user_input"

            case "$user_input" in
                "") # any input is ok
                    if ! [ "$invalid" ]; then
                        state=0
                        break
                    fi
                    # use invalid message
                    msg_invalid_input "$question > $invalid : "
                    ;;
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
                ${true_all}|${true_all:0:1})
                    state=0
                    user_input="${true_all}"
                    eval "${CONFIRMED_VAR}=${true}"
                    break
                    ;;
                ${false_all}|${false_all:0:1})
                    state=1
                    user_input="${false_all}"
                    eval "${CONFIRMED_VAR}=${false}"
                    break
                    ;;
                help )
                    msg_help "$(printf "$help")"

                    ;;
                * )
                    # Check for extra options
                    if [ "$extra" ];then
                        debug "   get_user_input: checking EXTRA OPTIONS MATCH $user_input"
                        for opt in "${extra[@]}"; do
                            if [[ "$opt" =~ ^$user_input ]]; then
                                debug "   get_user_input: $user_input MATCHED -> $opt"
                                user_input="$opt"
                                state=0
                                break
                            fi
                        done
                        if [ $state -eq 0 ];then break;fi
                    fi

                    # any input is ok
                    if ! [ "$invalid" ]; then
                        debug "   get_user_input: NO INVALID ANSWER"
                        state=0
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
      * ) if [ "$1" ];then
            extra_lines+=("$1")
          fi;;
    esac
    shift
  done

  local line
  local lines=""
  for line in "${extra_lines[@]}"; do
    lines="$lines\n$spacer $line"
  done

  debug "   CONFIRMED_VAR=${CONFIRMED_VAR}"
  debug "   CONFIRMED_VAR value=${!CONFIRMED_VAR}"

  if ! [ "${!CONFIRMED_VAR}" ] && ! [ "$confirmed" ]; then
      local options
      local text

      if [ "$CONFIRMED_VAR" ]; then
          options="$(printf "(%by%b)es, (%bY%b)es all, (%bn%b)o, (%bN%b)o all [%byes%b] : "  \
                     $yellow $rc $yellow $rc $yellow $rc $yellow $rc $c_default $rc)"
      else
          options="$(printf "(%by%b)es, (%bn%b)o, [%byes%b] : "  \
                     $yellow $rc $yellow $rc $c_default $rc)"
      fi

      text="$(printf "Would you like to %b%s%b %s %b%s%b%b? \n$spacer $options" \
             "$hc_user" "$action" $rc "$prefix" "$hc_user" "$topic" $rc "$lines" )"

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

  confirmed="${confirmed:-${!CONFIRMED_VAR}}"

  if [ "$confirmed" != "false" ]; then
    task "$(cap_first "${action%e}")ing $DRY_RUN $prefix" "$(printf "%b$topic" "$hc_topic")" "$lines"
    return 0
  else
    task "You skipped $action for $prefix" "$(printf "%b$topic" "$hc_topic")" "$lines"
    return 1
  fi
}
