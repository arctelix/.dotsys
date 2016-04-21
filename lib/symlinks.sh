#!/bin/sh

# Symlink functions
# Author: arctelix

# All functions pertaining to symlinks

# Manage all topic symlinks
# options:
# --unlink | -u |  : (followed by unlink option)
# --link | -l : (followed by link option)
# example: unlink and confirm delete for all (bypass confirmation)
# $ topic_symlinks topic_name --unlink -c "delete"
symlink_topic () {
  local usage="symlink_topic <action> [<confirm>] [<topic>]"
  local usage_full="
  Tasks (required)
    -i | install
    -x | uninstall
    -u | upgrade
    -r | update
  Options:
    -c --confirm <type> Pre confirm the action (see symlink & unlink for types)
  Example usage:
    # link vim and pre confirm delete for all symlinks
    symlink_topic link vim confirm delete
    # unlink vim and pre confirm restore backups for all symlinks
    symlink_topic unlink vim confirm restore"

  # Reset the persist state
  local SYMLINK_STATE=

  local home="$(user_home_dir)"

  required_params 2 "$@"
  local action=
  local topic=


  case "$1" in
    -i | install )    action="link" ;;
    -x | uninstall )  action="unlink" ;;
    -u | upgrade )    action="upgrade" ;;
    -r | update )     action="update" ;;
    * )  error "Not a valid action: $1"
         show_usage ;;
  esac
  shift


  while [[ $# > 0 ]]; do
    case "$1" in
      -d | delete )       SYMLINK_STATE="delete" ;;
      -b | backup )       SYMLINK_STATE="backup" ;;
      -rb | restore )     SYMLINK_STATE="restore" ;;
      -s | skip  )        SYMLINK_STATE="skip" ;;
      -c | --confirm )    SYMLINK_STATE="$2"; shift;;
      * )  uncaught_case "$1" "topic";;
    esac
    shift
  done

  # Reset SYMLINK_STATE if invalid
  if ! [[ "$SYMLINK_STATE"  =~ ^(delete|backup|skip)$ ]]; then
    SYMLINK_STATE=
  fi

  required_vars "action" "topic"

  local symlinks
  local dst_path

  # handle dotsys topic
  if [ "$topic" = "dotsys" ]; then
     symlinks=("$(find "${DOTSYS_REPOSITORY}/bin" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')")
     dst_path="${USER_BIN}/"

  # all other topics
  else
     # Find files and directories named *.symlink below each topic directory, exclude dot files.
     symlinks="$(/usr/bin/find "$(topic_dir $topic)" -mindepth 1 -maxdepth 1 \( -type f -or -type d \) -name '*.symlink' -not -name '\.*')"
     dst_path="$home/."
  fi


  while IFS=$'\n' read -r src; do
    # No simlinks found
    if [[ -z "$src" ]]; then
      success "$(printf "No symlinks required for %b%s%b" $light_green $topic $rc )"
      continue
    fi

    dst="${dst_path}$(basename "${src%.symlink}")"


    if [ "$action" = "link" ] ; then
      symlink "$src" "$dst"

    elif [ "$action" = "unlink" ]; then
      unlink "$dst"

    elif [ "$action" = "upgrade" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "update" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "freeze" ]; then
      echo freeze_sumlinks not_implimented
    fi

  done <<< "$symlinks"
}

# Unlink a singe file or directory
unlink(){

  local usage="unlink [<confirm>] <file> [<confirm>]"
  local usage_full="
  Options
    -d | delete
    -b | backup
    -r | restore
    -s | skip
  Example usage:
    # Unlink file and restore backup
    unlink restore ~/path/file.sh"

  required_params 1 "$@"
  local link=

  # OPTIONS (bypass confirmation)

  while [[ $# > 0 ]]; do
    case $1 in
      -b | backup ) SYMLINK_STATE=restore ;; # same as restore
      -rb | restore ) SYMLINK_STATE=restore ;;
      -d | delete )  SYMLINK_STATE=delete ;;
      -s | skip )    SYMLINK_STATE=skip ;;
      * ) uncaught_case "$1" "link" ;;
    esac
    shift
  done
  required_vars "link"

  local backup="${link}.backup"
  local type="$(path_type "$link")"
  local user_input=
  local action=

  # does not exits
  if [ ! -e "$link" ]; then
    warn "$(printf "Nothing to unlink at %b%s%b
         Run 'dotsys install ${topic}' to add the symlink" $light_green $link $rc)"
    return
  fi

  # If target is not a symlink skip it (this is an original file!)
  if [ ! -L "$link" ]; then
    fail "$(printf "Unlink skipped the $type %b%s%b because it is not a symlink!" $light_green $link $rc)"
    return
  fi

  local link_target="$(full_path "$link")"

  # check for confirmation status
  if [ -L "$link" ] && [ -z "$SYMLINK_STATE" ]; then
    user "$(printf "The $type %b%s%b
         $spacer is linked to %b%s%b
         $spacer How do you want to unlink it?
         $spacer (%bd%b)elete, (%bD%b) all, (%br%b)estore backup, (%bR%b) all, (%bs%b)kip, (%bS%b) all : " \
         $green "$link" $rc \
         $green "$link_target" $rc \
         $red $rc \
         $red $rc \
         $yellow $rc \
         $yellow $rc \
         $green $rc \
         $green $rc)"
    while true; do
      # Read from tty, needed because we read in outer loop.
      read user_input < /dev/tty

      case "$user_input" in
        d )
          action=delete
          break
          ;;
        D )
          SYMLINK_STATE=delete
          break
          ;;
        r )
          action=restore
          break
          ;;
        R )
          SYMLINK_STATE=restore
          break
          ;;
        s )
          action=skip
          break
          ;;
        S )
          SYMLINK_STATE=skip
          break
          ;;
        * )
          ;;
      esac
    done
    printf "$clear_line $clear_line_above $clear_line_above $clear_line_above"
  fi


  action=${action:-$SYMLINK_STATE}

  # Skip symlink
  if [ "$action" == "skip" ]; then
    success "$(printf "Unlink skipped by user %b%s%b == %b%s%b" $green "$link" $rc $green "$link_target" $rc)"

  # Remove symlink and restore backup
  elif [ "$action" == "restore" ]; then
    restore_backup_file "$link"
    if [ $? -eq 0 ]; then
      success "$(printf "Unlinked and backup restored %b%s%b -> %b%s%b" $green "$backup" $rc $green "$link" $rc)"
    else
      success "$(printf "Unlinked %b%s%b, but %b%s%b not found" $green "$link"  $rc $green "$backup" $rc)"
    fi

  # Delete the symlink
  elif [ "$action" == "delete" ]; then # "false" or empty]
    rm -rf "$link"
    success "$(printf "Unlinked and removed %b%s%b" $green "$link" $rc)"
  fi

}


# symLinks a single file
symlink () {

  local usage="symlink [<action>] <source> <destination>"
  local usage_full="
  Options
    -d | delete
    -b | backup
    -s | skip
  Example usage:
    # Link file and make backup of original if it exists
    unlink backup ~/path/file.sh"


  local action=
  local user_input=

  required_params 2 "$@"
  local src=
  local dst=

  while [[ $# > 0 ]]; do
    case $1 in
      -d | delete )    SYMLINK_STATE=delete ;;
      -b | backup )    SYMLINK_STATE=backup ;;
      -s | skip )      SYMLINK_STATE=skip ;;
      * )  uncaught_case "$1" "src" "dst" ;;
    esac
    shift
  done
  required_vars "src" "dst"

  # file or directory?
  local type="$(path_type "$src")"

  local dst_full_target="$(full_path "$dst")"
  src="$(full_path "$src")"


  # Get confirmation if no SYMLINK_STATE
  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ] && [ -z "$SYMLINK_STATE" ]; then
    if [ "$dst_full_target" = "$src" ]; then
      success "$(printf "Symlink already linked %b%s%b == %b%s%b" $green "$dst_full_target" $rc $green "$src" $rc)"
      return
    else
       user "$(printf "Existing $type %b%s%b
         will be linked to %b%s%b
         What do you want to do?
         (%bs%b)kip, (%bS%b) all, (%bo%b)verwrite, (%bO%b) all, (%bb%b)ackup, (%bB%b) all : " \
         $green "$dst" $rc \
         $green "$src" $rc \
         $light_yellow $rc \
         $light_yellow $rc \
         $light_yellow $rc \
         $light_yellow $rc \
         $light_yellow $rc \
         $light_yellow $rc)"

      while true; do
        # Read from tty, needed because we read in outer loop.
        read user_input < /dev/tty

        case "$user_input" in
          o )
            action=delete
            break
            ;;
          O )
            SYMLINK_STATE=delete
            break
            ;;
          b )
            action=backup
            break
            ;;
          B )
            SYMLINK_STATE=backup
            break
            ;;
          s )
            action=skip
            break
            ;;
          S )
            SYMLINK_STATE=skip
            break
            ;;
          * )
            ;;
        esac
      done
      printf "$clear_line $clear_line_above $clear_line_above $clear_line_above"
    fi
  fi

  action=${action:-$SYMLINK_STATE}

  if [ "$action" == "skip" ]; then
    success "$(printf "Symlink skipped %b%s%b == %b%s%b" $green "$dst" $rc $green "$dst" $rc)"

  elif [ "$action" == "delete" ]; then
    rm -rf "$dst"
    success "$(printf "Symlink overwrote %b%s%b" $green "$dst" $rc)"

  elif [ "$action" == "backup" ]; then
    mv "$dst" "$dst.backup"
    success "$(printf "Symlink backed up %b%s%b -> %b%s%b" $green "$dst" $rc $green "${dst}.backup" $rc)"
  fi

  if [ "$action" != "skip" ]; then
    # Create native symlinks on Windows.
    export CYGWIN=winsymlinks:nativestrict
    ln -s "$src" "$dst"
    success "$(printf "Symlink linked %b%s%b -> %b%s%b" $green "$src" $rc $green "$dst"  $rc)"
  fi
}

# Restores a backup
restore_backup_file(){
  local file="$1"
  local backup="${dst}.backup"
  if [ -f backup ];then
    rm -rf "$file"
    mv "$backup" "$file"
    return 0
  fi
  return 1
}


