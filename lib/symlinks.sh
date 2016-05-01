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
  local SYMLINK_CONFIRMED="$GLOBAL_CONFIRMED"

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
      -d | delete )       SYMLINK_CONFIRMED="delete" ;;
      -b | backup )       SYMLINK_CONFIRMED="backup" ;;
      -rb | restore )     SYMLINK_CONFIRMED="restore" ;;
      -s | skip  )        SYMLINK_CONFIRMED="skip" ;;
      -c | --confirm )    SYMLINK_CONFIRMED="$2"; shift;;
      * )  uncaught_case "$1" "topic";;
    esac
    shift
  done

  # Reset SYMLINK_CONFIRMED if invalid
  if ! [[ "$SYMLINK_CONFIRMED"  =~ ^(delete|backup|skip)$ ]]; then
    SYMLINK_CONFIRMED=
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
      success "$(printf "No symlinks required %sfor %b%s%b" "$DRY_RUN" $light_green $topic $rc )"
      continue
    fi

    dst="${dst_path}$(basename "${src%.symlink}")"

    # check for config  *.symlink -> path/name
    local link_cfg="$(get_topic_config_val "$topic" "symlinks")"
    debug "-- symlink_topic link_cfg: $link_cfg"
    for link in $link_cfg; do
      local src_name="$(basename "$src")"
      local alt_name="${link%-\>*}"
      debug "   symlink_topic CHECKING: $src_name = $alt_name"
      # check for file name match *.symlink
      if [ "$src_name" = "$alt_name" ]; then
         dst="${link#*-\>}"
         mkdir -p "$(dirname "$dst")"
         debug "   symlink_topic MATCHED $alt_name -> $dst"
         break
      fi
    done


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
      -b | backup ) SYMLINK_CONFIRMED=restore ;; # same as restore
      -rb | restore ) SYMLINK_CONFIRMED=restore ;;
      -d | delete )  SYMLINK_CONFIRMED=delete ;;
      -s | skip )    SYMLINK_CONFIRMED=skip ;;
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
    success "$(printf "Nothing to unlink at %s%b%s%b" "$DRY_RUN" $light_green $link $rc)"
    return
  fi

  # If target is not a symlink skip it (this is an original file!)
  if [ ! -L "$link" ]; then
    fail "$(printf "$(cap_first "$type") is not a symlink %s%b$link%b !" "$DRY_RUN" $light_green  $rc)"
    warn "If you want to remove this file, please do so manually."
    return
  fi

  local link_target="$(full_path "$link")"
  local link_name="$(basename "$link")"

  # check for confirmation status
  if [ -L "$link" ] && [ -z "$SYMLINK_CONFIRMED" ]; then
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
          SYMLINK_CONFIRMED=delete
          break
          ;;
        r )
          action=restore
          break
          ;;
        R )
          SYMLINK_CONFIRMED=restore
          break
          ;;
        s )
          action=skip
          break
          ;;
        S )
          SYMLINK_CONFIRMED=skip
          break
          ;;
        * )
          ;;
      esac
    done
    printf "$clear_line $clear_line_above $clear_line_above $clear_line_above"
  fi


  action=${action:-$SYMLINK_CONFIRMED}

  local skip_reason="skipped "
  if [ "$DRY_RUN" ]; then
      skip_reason="$DRY_RUN"
  fi

  # Skip symlink
  if [ "$action" == "skip" ]; then
    if ! [ -f "$backup" ];then backup="none";fi
    success "$(printf "Unlink %sfor %b%s's %s%b
                      $spacer existing $type : %b%s%b
                      $spacer linked to : %b%s%b
                      $spacer backup $type : %b%s%b" \
                      "$skip_reason" $green "$topic" "$link_name" $rc \
                      $green "$link" $rc \
                      $green "$link_target" $rc \
                      $green "$backup" $rc)"

  # Remove symlink and restore backup
  elif [ "$action" == "restore" ] || [ "$action" == "backup" ]; then
    restore_backup_file "$link"
    if [ $? -eq 0 ]; then
      success "$(printf "Restored backup %b%s%b
              $spacer -> %b%s%b" $green "$backup" $rc $green "$link" $rc)"
    else
      warn "$(printf "No backup for %s" $green "$link"  $rc)"
    fi
  # Delete the symlink
  fi

  if [ "$action" != "skip" ]; then # "false" or empty]
    rm -rf "$link"
    if [ $? -eq 0 ]; then
      success "$(printf "Deleted %b%s%b" $green "$link" $rc)"
    else
      fail "$(printf "Problem deleting %b%s%b" $green "$link" $rc)"
    fi
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
      -d | delete )    SYMLINK_CONFIRMED=delete ;;
      -b | backup )    SYMLINK_CONFIRMED=backup ;;
      -s | skip )      SYMLINK_CONFIRMED=skip ;;
      * )  uncaught_case "$1" "src" "dst" ;;
    esac
    shift
  done

  # shortcut for typical $src -> $HOME/.$dst
  if ! [ "$dst" ]; then
    dst="$HOME/.$(basename "${src%.symlink}")"
  fi

  required_vars "src" "dst"

  # file or directory?
  local type="$(path_type "$src")"

  local dst_full_target="$(full_path "$dst")"
  local dst_name="$(basename "$dst")"
  src="$(full_path "$src")"


  local exists=
  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]; then exists="true";fi

  if [ "$exists" ] && [ "$dst_full_target" = "$src" ]; then
      success "$(printf "Symlink %sexists for %s %b%s%b" "$DRY_RUN" "$type" $green "$dst_name" $rc)"
      return
  fi

  # Get confirmation if no SYMLINK_CONFIRMED
  if [ "$exists" ] && [ -z "$SYMLINK_CONFIRMED" ]; then
     user "$(printf "Existing $type %b%s%b
       should be linked to %b%s%b
       What do you want to do?
       (%bs%b)kip, (%bS%b) all, (%bo%b)verwrite, (%bO%b) all, (%bb%b)ackup, (%bB%b) all : " \
       $green "$dst" $rc \
       $green "$src" $rc \
       $dark_yellow $rc \
       $dark_yellow $rc \
       $dark_yellow $rc \
       $dark_yellow $rc \
       $dark_yellow $rc \
       $dark_yellow $rc)"

    while true; do
      # Read from tty, needed because we read in outer loop.
      read user_input < /dev/tty

      case "$user_input" in
        o )
          action=delete
          break
          ;;
        O )
          SYMLINK_CONFIRMED=delete
          break
          ;;
        b )
          action=backup
          break
          ;;
        B )
          SYMLINK_CONFIRMED=backup
          break
          ;;
        s )
          action=skip
          break
          ;;
        S )
          SYMLINK_CONFIRMED=skip
          break
          ;;
        * )
          ;;
      esac
    done
    printf "$clear_line $clear_line_above $clear_line_above $clear_line_above"

  fi

  action=${action:-$SYMLINK_CONFIRMED}

  local message=
  local skip_reason="skipped "
  if [ "$DRY_RUN" ]; then
      skip_reason="$DRY_RUN"
  fi

  if [ "$action" == "skip" ]; then
    success "$(printf "Symlink %sfor %b%s%b:" "$skip_reason" $green "$dst_name" $rc)"
    # incorrect link
    if [ -L "$dst" ]; then
      warn "$(printf "Symlinked $type : %b%s%b
                      $spacer currently linked to : %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$dst_full_target" $rc $green "$src" $rc)"
    # Original file not linked
    elif [ "$exists" ] && [ "$dst_full_target" = "$dst" ]; then
      warn "$(printf "Original $type : %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$src" $rc)"

    # dest not exist
    else
      warn "$(printf "No $type found at: %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$src" $rc)"

    fi

  elif [ "$action" == "delete" ] && [ "$exists" ]; then
    message="$(printf "Symlink overwrote %b%s%b" $green "$dst" $rc)"
    rm -rf "$dst"

  elif [ "$action" == "backup" ] && [ "$exists" ]; then
    # only create backup once
    if ! [ -f "${dst}.backup" ] ; then
      message="$(printf "Symlink backed up %b%s%b
      $spacer -> %b%s%b" $green "$dst" $rc $green "${dst}.backup" $rc)"
      mv "$dst" "${dst}.backup"
    else
      message="$(printf "Symlink overwrote %b%s%b
      $spacer already had backup -> %b%s%b" $green "$dst" $rc $green "${dst}.backup" $rc)"
      rm -rf "$dst"
    fi
  fi

  if [ "$message" ]; then
    if [ $? -eq 0 ]; then
      success "$message"
    else
      fail "$message"
    fi
  fi

  if [ "$action" != "skip" ]; then
    message="$(printf "Symlink linked %b%s%b
            $spacer -> %b%s%b" $green "$dst" $rc $green "$src"  $rc)"
    # Create native symlinks on Windows.
    export CYGWIN=winsymlinks:nativestrict
    ln -s "$src" "$dst"
    if [ $? -eq 0 ]; then
      success "$message"
    else
      fail "$message"
    fi
  fi
}

# Restores a backup
restore_backup_file(){
  local file="$1"
  local backup="${dst}.backup"
  if [ -f "$backup" ];then
    rm -rf "$file"
    mv "$backup" "$file"
    return 0
  fi
  return 1
}


