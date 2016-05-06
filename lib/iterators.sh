#!/bin/sh

# Iteration functions
# Author: arctelix
# Thanks to the following sources:
# https://github.com/agross/dotfiles
# https://github.com/holman/dotfiles
# https://github.com/webpro/dotfiles

# Iterates each topics for each platform
# interate_topic [-p function] function [function] [N]
# Accepts N functions to be executed for each topic
# optional first argument -p followed by a function to be executed for each platform
# all other arguments must be functions executed for each topic
# ex: $iterate_topics -p platform_func topic_func_one topic_func_two

# TODO: implement ability to confirm each topic and each task prior execution
# also allow to abort iteration at each confirmation.
# ie: Would you like to confirm each topic ? y/n
# ie: Would you like to confirm each topic task ? y/n
# ie: Would you like to TASK
# id: [Y]es [C]confirm_tasks [N]o [A]bort_all_topics

iterate_topics (){
  echo caller $0
  local task_name=$1
  shift

  # check for platform procedure
  if [ "$1" = "-p" ]; then
      local platform_procedure=$2
      shift # remove option
      shift # remove platform procedure
  fi

  local platforms="$(get_platform)"
  local platform
  while IFS=$'\n' read -r platform; do

    echo
    task "$task_name for platform ($platform)"
    echo

    $platform_procedure $platform

    # Find direct child directories (topics), exclude those starting with dots.
    local topics="$(/usr/bin/find "$(dotfiles_dir)" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')"
    while IFS=$'\n' read -r topic; do
      local topic_name="${topic##*/}"
      [[ -z "$topic" ]] && continue

      task "$topic_name ($platform) $task_name"

      # check for topic platform exclusions
      if platform_excluded "$topic" "$platform"; then
        success "$(printf "Excluded %b%s%b on %b%s%b" $green "$topic" $rc $green "$platform" $rc)"
        continue
      fi

      # execute balance of args (functions)
      for procedure in "${@}"; do
        $procedure $platform $topic
      done

    done <<< "$topics"
  done <<< "$platforms"

}
