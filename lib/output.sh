#!/bin/sh

# Terminal output
# Author: arctelix

# COLORS

black="\e[0;30m"
black_bold="\e[01;30m"

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

light_gray="\e[0;37m"
light_gray_bold="\e[01;37m"

dark_gray="\e[0;90m"
dark_gray_bold="\e[01;90m"

l_red="\e[0;91m"
l_red_bold="\e[01;91m"

l_green="\e[0;92m"
l_green_bold="\e[01;92m"

l_yellow="\e[0;93m"
l_yellow_bold="\e[01;93m"

l_blue="\e[94m"
l_blue_bold="\e[1;94m"

l_magenta="\e[0;95m"
l_magenta_bold="\e[01;95m"

l_cyan="\e[0;96m"
l_cyan_bold="\e[01;96m"

white="\e[0;97m"
white_bold="\e[01;97m"

rc="\e[0m" #reset color

clear_line="\r\e[K"
clear_line_above="\e[1A\r\e[K"

spacer="\r\e[K        " # indent from screen edge
indent="        " # indent from current position

# topic highlight color
thc=""

# user color
uc=$white
# user highlight color
uhc=$dark_white

# default value color
dvc=$l_blue

# code highlight color
_code=$magenta
_help=$l_blue

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
    local hcolor=$2
    shift; shift
    local i=0
    for a in "$@";do
        if is_even $i ; then
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
  printf  "%b%b%b" $_code "$1" $rc
}

# messages

msg () {
  local text="$(compile_text $yellow $dark_yellow "$@")"
  printf  "\r%b%b%b%b\n" $clear_line $yellow "$text" $rc
  log "MSG" "$@"
}

msg_help () {
  printf  "\r%b%b%b\n" $_help "$1" $rc
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
    printf "$state: $item" >> "$DOTSYS_REPOSITORY/debug.dslog"
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
            $other_func "Failed to $first_arg" "$@"
        fi
    fi
    return $state
}


# adds indent to all but first line
indent_lines () {
  local first
  local line

  if [ "$1" == "--prefix" ]; then
    local prefix="$2"
    shift
    shift
  fi

  local input="$1"

  # Take input from pipe
  if ! [ "$input" ]; then
      debug "$indent indent lines from pipe"
      #sed "s/^/$indent/g"
      while IFS= read -r line || [[ -n "$line" ]]; do
        # remove \r and replace with \r$indent
        echo "$indent $prefix$(echo "$line" | sed "s/$indent$(printf '\r')/$(printf '\r')$indent /g")"
      done

  # input from variable
  else
      debug "$indent indent lines from input"
      while read -r line || [[ -n "$line" ]]; do
        if ! [ "$first" ];then
            first="true"
            printf "%b\n" "$line"
        else
            printf "$indent $prefix%b\n" "$line"
        fi
      done <<< $input
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

# Capitolize first letter for string
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

print_logo (){

if ! get_state_value "user" "show_logo" || [ $SHOW_LOGO -eq 1 ] || ! verbose_mode; then
    return
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

    info "Active repo : " "$(printf "%b%s%b" $thc $ACTIVE_REPO $rc)"
    info "Platform    : " "$(printf "%b%s%b" $thc $PLATFORM $rc)"
    info "App manager : " "$(printf "%b%s%b" $thc $DEFAULT_APP_MANAGER $rc)"
    info "Cmd manager : " "$(printf "%b%s%b" $thc $DEFAULT_CMD_MANAGER $rc)"
    info "User bin    : " "$(printf "%b%s%b" $thc $PLATFORM_USER_BIN $rc)"
    info "User home   : " "$(printf "%b%s%b" $thc $PLATFORM_USER_HOME $rc)"

    local count=${#topics[@]}
    if [ $count -eq 0 ]; then count="all"; fi
    info "$(printf "$(cap_first "${action}ing") %b%s%b" $thc "$count topics" $rc)"

    # make sure it's only seen once
    SHOW_STATS=1
}

# FORMAT SCRIPT OUTPUT

output_script() {
#  read(){
#      #debug "=========read"
#      if [[ $1 = -p ]]; then
#      set -- "$1" "$2"$'\n' "${@:3}"
#      fi
#      builtin read "$@"
#  }
#  export -f read
#  debug "=========read_tty $@"

   #TODO: Tried everything imaginable to indent lines & get prompts for brew
   #script -q /dev/null "$@" 2>&1 | indent_lines
   #script -q /dev/null sh -i "$@" 2>&1 | indent_lines
   #sh -i "$@" 2>&1 | indent_lines
   #"$@" | indent_lines
   debug "output_script $@"
   #script -q /dev/null "$@"
   sh -i "$@"
   local state=$?
   debug "   output_script state=$state"
   return $state

#  unset -f read
#  debug "=========read_tty unset"
  #"$@"
}

test_read_tty () {
    #chmod +x "$(dotsys_dir)/lib/test.sh"
    #"$(dotsys_dir)/lib/test.sh" get_name_test
    # sed "s/^/printf
    #read_tty script -q /dev/null ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
    output_script "$(builtin_topic_dir)brew/topic.sh" install

}
