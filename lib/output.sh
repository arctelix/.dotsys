#!/bin/bash

# Terminal output
# Author: arctelix

# BASIC OUTPUT ( ALL SCREEN OUTPUT MUST USE THESE METHODS )

user () {
  printf   "\r%b[%b  ?   %b] %b%b" $clear_line $dark_yellow $rc "$@" $rc
  log "USER" "$@"
}

info () {
  local text="$(compile_text $blue $dark_blue "$@")"
  printf   "\r%b[%b INFO %b] %b%b\n" $clear_line $dark_blue $rc "$text" $rc
  log "INFO" "$@"
}

warn () {
  local text="$(compile_text $yellow $dark_yellow "$@")"
  printf   "\r%b[%b WARN %b] %b%b\n" $clear_line $dark_yellow $rc "$text" $rc
  log "WARN" "$@"
}

success () {
  local text="$(compile_text $green $dark_green "$@")"
  printf "\r%b[%b  OK  %b] %b%b\n" $clear_line $dark_green $rc "$text" $rc
  log "SUCCESS" "$@"
}

fail () {
  local text="$(compile_text $red $dark_red "$@")"
  printf  "\r%b[%b FAIL %b] %b%b\n" $clear_line $dark_red $rc "$text" $rc
  debug_log "FAIL" "$@"
}

task() {
  local text="$(compile_text $cyan $dark_cyan "$@")"
  printf  "\r%b[%b TASK %b] %b%b\n" $clear_line $dark_cyan $rc "$text" $rc
  log "TASK" "$@"
}

# alternates input text height "normal" "hilight" "normal"
compile_text () {
    local color=$1
    pc=$1
    local hcolor=$2
    shift; shift
    local i=0
    for a in "$@";do
        if [[ $((i % 2)) -eq 0 ]] ; then
            printf "%b%b " $color "$a"
        else
            printf "%b%b " $hcolor "$a"
        fi
        i=$((i+1))
    done
}

is_even () {
    local val=$1
    [[ $((val % 2)) -eq 0 ]]
    return $?
}

# otehr text formatting

code () {
  printf  "%b%b%b" $c_code "$1" $pc
}

# messages

msg () {
  local text="$(compile_text $yellow $dark_yellow "$@")"
  printf  "\r%b%b%b%b\n" $clear_line $yellow "$text" $rc
  log "MSG" "$@"
}

msg_help () {
  local text="$(compile_text $c_help $c_code "$@")"
  printf  "\r%b%b%b\n" $c_help "$text" $rc
  log "HELP" "$@"
}

error () {
  local text="$(compile_text $red $dark_red "$@")"
  printf  "\r\n%b%bERROR:  %b%b%b\n\n" $clear_line $dark_red $red "$text" $rc
  debug_log "ERROR" "$1"
  log "ERROR" "$@"
}

freeze_msg () {
    local task="$1"
    local desc="$2"
    local items="$3"

    printf  "$spacer %b$task%b : $desc\n" $green $rc
    log "$indent $task" "$desc"

    if ! [ "$items" ]; then return;fi
    local item
    while IFS=$'\n' read -r item; do
        printf  "$spacer - %b$item%b\n" $green $rc
        log "$indent - $item"
    done <<< "$items"
}

# END BASIC OUTPUT ( ALL OTHER OUTPUT MUST USE ABOVE METHODS )

log () {
    if ! [ "$LOG_FILE" ]; then return ;fi
    local state="$1"
    local item="$2"
    if [ "$item" ]; then
        echo "$state: $item" >> $LOG_FILE
    else
        echo "$state" >> $LOG_FILE
    fi
}

debug_log () {
    local state="$1"
    local item="$2"
    printf "%s : %s" "$state" "$item" >> "$DOTSYS_REPOSITORY/debug.dslog"
    log "$state" "$item"
}

success_or_fail () {
    local state=$1
    local action="$2"
    shift; shift
    func_or_func_msg success fail $state "$action" "$@"
}

success_or_error () {
    local state=$1
    local action="$2"
    shift; shift
    func_or_func_msg success error $state "$action" "$@"
    if ! [ $? -eq 0 ]; then exit; fi
}

success_or_none () {
    local state=$1
    local action="$2"
    shift; shift
    func_or_func_msg success pass $state "$action" "$@"
}

func_or_func_msg () {
    local zero_func="$1"
    local other_func="$2"
    local state="$3"
    local action="$4"
    local first_arg="$5"
    shift; shift; shift; shift; shift

    # Do not print message for codes 20-29 (script msg)
    if [ $state -ge 20 ] && [ $state -le 29 ]; then return;fi

    if [ $state -eq 0 ]; then
        if [ "$action" ]; then
            action="${action%ed}"
            action="$(cap_first "${action%e}ed")"
            $zero_func "$action $first_arg" "$@"
        else
            $zero_func "$first_arg" "$@"
        fi
    else
        if [ "$action" ]; then
            $other_func "Failed to $action $first_arg" "$@"
        else
            $other_func "$first_arg" "$@"
        fi
    fi
    return $state
}


# adds indent to all but first line
indent_lines () {

  local first
  local first_line
  local line
  local prefix
  local input

  usage="indent_lines [<option>]"
  usage_full="
      -p | --prefix     Prefix each line
      -f | --first      Leave first line
  "

  while [[ $# > 0 ]]; do
      case "$1" in
      -p | --prefix )      prefix="$2"; shift;;
      -f | --first )       first="$1" ;;
      *) input="${1:- }"
      esac
      shift
  done


  # Take input from pipe
  if ! [ "$input" ]; then
    debug "read lines from stdin"
    while IFS= read -r line || [[ -n "$line" ]]; do
        _indent_line "$line"
    done < "/dev/stdin"

  # Take input from variable
  else
    debug "read lines from input"
    while IFS= read -r line || [[ -n "$line" ]]; do
        _indent_line "$line"
    done <<< "$input"
  fi

  #sed "s/^/$indent/g"
}

_indent_line (){
    local line="$1"
    if [ "$first" ] && [ ! "$first_line" ];then
        first_line="true"
        echo "$line"
    else
        # remove \r and replace with \r$indent
        echo "$indent $prefix$(echo "$line" | sed "s/$indent$(printf '\r')/$(printf '\r')$indent /g")"
    fi
}

abs_to_rel_path () {
    debug "$@"
    local paths="$1"
    local file="$(basename "$path")"
    local topic="$(basename "${path%/*}")"
    local repo="$(basename "${path%/*/*}")"
    local user="$(basename "${path%/*/*/*}")"
    echo "$user/$repo/$topic/$file"
}

# Converts variable list to indented lines
indent_list () {
  local list="$1"
  local i

  # Take input from pipe
  if ! [ "$list" ]; then
      while read -r i || [[ -n "$line" ]];do
        list="$list$i "
      done
  fi

  # input from variable
  for i in $list;do
      echo "$indent $i"
  done
}


# invalid option
msg_invalid_input (){
    printf "$clear_line"
    printf "$celar_line_above"
    clear_lines "$1"
    user "$1"
}

clear_lines () {
    printf "$clear_line"
    if ! [ "$1" ];then return;fi
    local lines=$(printf "%b" "$1" | wc -l)
    lines=$lines+1 #clears all lines
    local sub=${2:-0} # add (+#) or subtract (-#) lines to clear
    local c
    for (( c=1; c<=$lines+$sub; c++ )); do printf "$clear_line_above"; done
}

print_logo (){

if [ "$1" != "--force" ]; then
    if ! config_show_logo || [ $SHOW_LOGO -eq 1 ] || ! verbose_mode; then
        return
    fi
fi

local message="Welcome To Dotsys $(get_user_name)"

printf "%b
  (          )
  )\ )    ( /(   (
 (()/( (  )\()|  )\ ) (
  ((_)))\(_))/)\(()/( )\\
  _| |((_) |_((_))(_)|(_)
/ _\` / _ \  _(_-< || (_-<
\__,_\___/\__/__/\_, /__/
                 |__/

$message%b\n\n" $dark_red $rc

# make sure it's only seen once
SHOW_LOGO=1
}

print_stats () {
    if ! get_state_value "user" "show_stats" || [ $SHOW_STATS -eq 1 ] || ! verbose_mode; then
        return
    fi

    info "Active repo : " "$(printf "%b%s%b" "$hc_topic" $ACTIVE_REPO $rc)"
    info "Active shell: " "$(printf "%b%s%b" "$hc_topic" $ACTIVE_SHELL $rc)"
    info "Platform    : " "$(printf "%b%s%b" "$hc_topic" $PLATFORM $rc)"
    info "App manager : " "$(printf "%b%s%b" "$hc_topic" $DEFAULT_APP_MANAGER $rc)"
    info "Cmd manager : " "$(printf "%b%s%b" "$hc_topic" $DEFAULT_CMD_MANAGER $rc)"
    info "User bin    : " "$(printf "%b%s%b" "$hc_topic" $PLATFORM_USER_BIN $rc)"
    info "User home   : " "$(printf "%b%s%b" "$hc_topic" $PLATFORM_USER_HOME $rc)"

    local count=${#topics[@]}
    if [ $count -eq 0 ]; then count="all"; fi
    info "$(printf "$(cap_first "${action}ing") %b%s%b" "$hc_topic" "$count topics" $rc)"

    # make sure it's only seen once
    SHOW_STATS=1
}

# FORMAT SCRIPT OUTPUT

output_script() {

   local state
   local pstate

   debug "output_script $@"

#   read(){
#      dprint "=========read $*"
#      if [[ $1 = -p ]]; then
#      set -- "$1" "$2"$'\n' "${@:3}"
#      fi
#      builtin read "$@"
#    }
#    export -f read
#    dprint "=========read_tty $@"

   #TODO: Tried everything imaginable to indent lines & still get prompts
#   echo "---------------"
#   script -q /dev/null "$@" 2>&1 | indent_lines
#   echo "---------------"
#   script -q /dev/null sh -i "$@" 2>&1 | indent_lines
#   echo "---------------"
#   #script -q /dev/null "$@" | indent_lines
#    echo "---------------"
#   sh -i "$@" 2>&1 | indent_lines
#   echo "---------------"
#   sh --init-file -i "$@" 2>&1
#   echo "---------------"
#   sh --init-file -i "$@" 2>&1 | indent_lines

   local script="$1"
   shift

   # DO NOT USE "$@"  HERE (script executes params)
   (source "$script")
   state=$?

   #pstate=${PIPESTATUS[0]}

   debug "   output_script state=$state pstate=${PIPESTATUS[0]}"

#   unset -f read
#   dprint "=========read_tty unset"
#   return ${pstate:-$state}
    return $state
}

test_read_tty () {
    #chmod +x "$(dotsys_dir)/lib/test.sh"
    #"$(dotsys_dir)/lib/test.sh" get_name_test
    # sed "s/^/printf
    #read_tty script -q /dev/null ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
    output_script "$(builtin_topic_dir)brew/topic.sh" install
}
