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
    symlink_topic link vim confirm repo
    # unlink vim and pre confirm restore backups for all symlinks
    symlink_topic unlink vim confirm original"

  required_params 2 "$@"
  local action=
  local topic=


  case "$1" in
    -i | install )    action="link" ;;
    -x | uninstall )  action="unlink" ;;
    -g | upgrade )    action="upgrade" ;;
    -u | update )     action="update" ;;
    -f | freeze )     action="freeze" ;;
    * )  error "Not a valid action: $1"
         show_usage ;;
  esac
  shift


  while [[ $# > 0 ]]; do
    case "$1" in
      -c | --confirm )    SYMLINK_CONFIRMED="$2"; shift;;
      * )  uncaught_case "$1" "topic";;
    esac
    shift
  done

  # Reset SYMLINK_CONFIRMED if not a valid symlink confirmation
  if ! [[ "$SYMLINK_CONFIRMED"  =~ ^(default|original|repo|none|skip|dryrun)$ ]]; then
    SYMLINK_CONFIRMED=
  fi

  required_vars "action" "topic"

  local symlinks
  local dst_path

  # handle dotsys topic
  if [ "$topic" = "dotsys" ]; then
     symlinks=("$(find "${DOTSYS_REPOSITORY}/bin" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')")
     dst_path="${PLATFORM_USER_BIN}/"

  # all other topics
  else
     symlinks="$(/usr/bin/find "$(topic_dir "$topic")" -mindepth 1 -maxdepth 1 \( -type f -or -type d \) -name '*.stub' -o -name '*.symlink' -not -name '\.*')"
  fi
  local last_stub # tracks last stub found
  local src
  while IFS=$'\n' read -r src; do

    local filename_noext="${src%.*}"
    local stub="${filename_noext}.stub"

    debug "src  : $src"
    debug "stub : $stub"

    # No simlinks found
    if [[ -z "$src" ]] && [ "$action" != "freeze" ]; then
      success "$(printf "No symlinks required %s for %b%s%b" "$DRY_RUN" $light_green $topic $rc )"
      continue
    fi

    if [ "$last_stub" = "$filename_noext" ]; then
        debug "symlink_topic: already linked -> $src"
        continue
    fi

    if [ "$src" = "$stub" ]; then
        last_stub="$filename_noext"
        debug "symlink_topic: symlinking stub -> $src"
    fi

    # check for alternate dst in config  *.symlink -> path/name
    dst="$(get_symlink_dst "$src" "$dst_path")"

    debug "$src -> $dst"

    if [ "$action" = "link" ] ; then
      symlink "$src" "$dst"

    elif [ "$action" = "unlink" ]; then
      unlink "$dst"

    elif [ "$action" = "upgrade" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "update" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "freeze" ]; then
      if [ "$(drealpath "$dst")" == "$src" ]; then
        freeze_msg "symlink" "$dst -> $src"
      fi
    fi

  done <<< "$symlinks"
}


# symLinks a single file
symlink () {

  local usage="symlink [<action>] <source> <destination>"
  local usage_full="
  Options
    -d | default  Use default (repo)
    -o | original Use the original version found on system
    -r | repo     Use the repo version if original version is found
    -s | skip     Report state and do nothing
         dryrun   Report state and do nothing
  Example usage:
    # Link file and make backup of original if it exists
    symlink repo ~/path/file.sh"


  local action=
  local user_input=

  required_params 2 "$@"
  local src=
  local dst=

  while [[ $# > 0 ]]; do
    case $1 in
      -d | default )    SYMLINK_CONFIRMED=default ;;
      -o | original )   SYMLINK_CONFIRMED=original ;;
      -r | repo )       SYMLINK_CONFIRMED=repo ;;
      -s | skip )       SYMLINK_CONFIRMED=skip ;;
      -n | none )       SYMLINK_CONFIRMED=skip ;;
      dryrun )          SYMLINK_CONFIRMED=skip ;;
      * )  uncaught_case "$1" "src" "dst" ;;
    esac
    shift
  done

  # Set default for confirmed
  if [ "$SYMLINK_CONFIRMED" = "default" ]; then SYMLINK_CONFIRMED="repo";fi

  # shortcut for typical $src -> $HOME/.$dst
  if ! [ "$dst" ]; then
    dst="$HOME/.$(basename "${src%.symlink}")"
  fi

  required_vars "src" "dst"

  # file or directory?
  local type="$(path_type "$src")"
  local dst_link_target="$(drealpath "$dst")"
  local dst_name="$(basename "$dst")"
  local message

  src="$(drealpath "$src")"
  stub="$(drealpath "${src%.*}.stub")"


  # target path matches source (do nothing)
  if [ "$dst_link_target" = "$src" ] && [ -L "$dst"  ]; then
      success "$(printf "Already linked %s %s %b%s%b" "$DRY_RUN" "$type" $green "$dst" $rc)"
      return
  fi

  local exists
  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]; then
    # not a link, so exits
    if ! [ -L "$dst" ]; then
      exists="true"
    # link exists only if target exists
    elif [ -f "$dst_link_target" ]; then
      exists="true"
    fi
  fi

  # Get confirmation if file already exists and not confirmed
  if [ "$exists" ] && [ -z "$SYMLINK_CONFIRMED" ]; then

     message="$(printf "Two versions of %b$(basename "$dst")%b were found:
                            $spacer original version : %b$dst_link_target%b
                            $spacer repo version : %b$src%b
                            $spacer Which version would you like to use?
                            $spacer %b(Don't stress, we'll backup any original files)%b" $green $rc $green $rc $green $rc $gray $rc)"

     user "$(printf "$message
             $spacer (%br%b)repo, (%bR%b)all, (%bo%b)original, (%bO%b)all (%bs%b)kip, (%bS%b)all: " \
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
        o )action=original; break;;
        O )SYMLINK_CONFIRMED=original; break;;
        r )action=repo; break;;
        R )SYMLINK_CONFIRMED=repo; break;;
        s )action=skip; break;;
        S )SYMLINK_CONFIRMED=skip; break;;
        * )
          ;;
      esac
    done
    printf "$clear_line $clear_line_above $clear_line_above $clear_line_above"

  fi

  action=${action:-$SYMLINK_CONFIRMED}

  local message=
  local skip_reason="skipped "
  if dry_run; then
      skip_reason="$DRY_RUN"
  fi

  if [ "$action" == "skip" ]; then

    success "$(printf "Symlink %s for %b%s%b:" "$skip_reason" $green "$dst_name" $rc)"
    # incorrect link
    if [ -L "$dst" ]; then
      warn "$(printf "Symlinked $type : %b%s%b
                      $spacer currently linked to : %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$dst_link_target" $rc $green "$src" $rc)"
    # original file not linked
    elif [ "$exists" ] && [ "$dst_link_target" = "$dst" ]; then
      warn "$(printf "original $type : %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$src" $rc)"

    # dest not exist
    else
      warn "$(printf "No $type found at: %b%s%b
                      $spacer should be linked to : %b%s%b" $green "$dst" $rc $green "$src" $rc)"

    fi

  # keep repo version
  elif [ "$action" == "repo" ] && [ "$exists" ]; then
    # backup original version
    remove_and_backup_file "original" "$dst"

  # keep original version
  elif [ "$action" == "original" ] && [ "$exists" ]; then
    # backup repo version
    remove_and_backup_file "repo" "$src"
    # move original to repo
    mv "$dst_link_target" "$src"
    success_or_fail $? "move" "original to repo"
  fi

  if [ "$action" != "skip" ]; then
    message="$(printf "%b%s%b
            $spacer -> %b%s%b" $green "$dst" $rc $green "$src"  $rc)"
    # Create native symlinks on Windows.
    export CYGWIN=winsymlinks:nativestrict
    ln -s "$src" "$dst"
    success_or_fail $? "link" "$message"
  fi
}

remove_and_backup_file(){
  local desc="$1"
  local file="$2"
  local backup="${file}.dsbak"

  if ! [ -f "$backup" ] ; then
      message="$(printf "up $desc version %b%s%b
      $spacer new backup -> %b%s%b" $green "$file" $rc $green "$backup" $rc)"
      mv "$file" "$backup"
      success_or_fail $? "back" "$message"
  else
      message="$(printf "$desc version %b%s%b
      $spacer existing backup -> %b%s%b" $green "$file" $rc $green "$backup" $rc)"
      rm -rf "$file"
      success_or_fail $? "remove" "$message"
  fi



  return $?
}


# Unlink a singe file or directory
unlink(){

  local usage="unlink [<confirm>] <file> [<confirm>]"
  local usage_full="
  Options
    -d | default       Use default (original)
    -o | original      replace symlink with the original backup ;;
    -r | repo          replace symlink with a copy of the repo's version  ;;
    -n | none          Just delete the symlink
    -s | skip          Do nothing just show the status (dry run)
         dryrun        Do nothing  just show the status (dry run)
  Example usage:
    # Unlink file and restore backup
    unlink original ~/path/file.sh"

  required_params 1 "$@"
  local link_file=

  # OPTIONS (bypass confirmation)

  while [[ $# > 0 ]]; do
    case $1 in
      -d | default )    SYMLINK_CONFIRMED=original ;;
      -r | repo )       SYMLINK_CONFIRMED=repo ;;
      -n | none )       SYMLINK_CONFIRMED=none ;;
      -o | original )   SYMLINK_CONFIRMED=original ;;
      -s | skip )       SYMLINK_CONFIRMED=skip ;;
           dryrun )     SYMLINK_CONFIRMED=skip ;;
      * ) uncaught_case "$1" "link_file" ;;
    esac
    shift
  done
  required_vars "link_file"

  # Set default for confirmed
  if [ "$SYMLINK_CONFIRMED" = "default" ]; then SYMLINK_CONFIRMED="original";fi

  # File does not exits
  if [ ! -e "$link_file" ]; then
    success "$(printf "Nothing to unlink at %s %b%s%b" "$DRY_RUN" $light_green $link_file $rc)"
    return
  fi

  local type="$(path_type "$link_file")"

  # If target is not a symlink skip it (this is an original file!)
  if [ ! -L "$link_file" ]; then
    fail "$(printf "$(cap_first "$type") is not a symlink %s %b$link_file%b !" "$DRY_RUN" $light_green  $rc)"
    warn "If you want to remove this file, please do so manually."
    return
  fi

  local backup="${link_file}.dsbak"
  local link_target="$(drealpath "$link_file")"
  local link_name="$(basename "$link_file")"
  local link_stub
  local user_input
  local action

  # We care about the .symlink not the .stub!
  if [ "${link_target%.stub}" != "$link_target" ]; then
        link_stub="$link_target"
        link_target="${link_target%.stub}.symlink"
  fi

  if ! [ "$SYMLINK_CONFIRMED" ]; then

      # No original file exists
      if ! [ -f "$backup" ]; then

          # repo has original file
          if [ -f "$link_target" ]; then
              get_user_input "No backup of $link_name was found,
                      $spacer keep a copy of the repo version?" \
                      --true "repo" --false "none" --confvar "SYMLINK_CONFIRMED" --required
              if [ $? -eq 0 ]; then action=repo ;fi
          fi

      # original file & repo file exist (not stub)
      elif [ -f "$link_target" ]; then

        user "$(printf "Two versions of the $type %b%s%b were found:
                $spacer %boriginal backup%b : $backup
                $spacer %bcurrent repo%b : $link_target
                $spacer Which version of the file would you like to keep?
                $spacer (%bo%b)riginal, (%bO%b)all, (%br%b)epo, (%bR%b)all, (%bn%b)one, (%bN%b)all : " \
                $green "$link_name" $rc \
                $green $rc \
                $green $rc \
                $green $rc $green $rc \
                $yellow $rc $yellow $rc \
                $blue $rc $blue $rc)"

        while true; do
          # Read from tty, needed because we read in outer loop.
          read user_input < /dev/tty

          case "$user_input" in
            c )action=origianl; break ;;
            C )SYMLINK_CONFIRMED=original; break ;;
            r )action=repo; break ;;
            R )SYMLINK_CONFIRMED=repo; break ;;
            n )action=none;break ;;
            N )SYMLINK_CONFIRMED=none; break ;;
            * )
              ;;
          esac
        done
        printf "$clear_line $clear_line_above $clear_line_above $clear_line_above $clear_line_above"

      # no file available to keep
      else
        action=none
      fi

  fi

  action=${action:-$SYMLINK_CONFIRMED}

  # Remove the file (if not skip)
  if [ "$action" != "skip" ]; then
    rm -rf "$link_file"
    success_or_none $? "remove" "$(printf "symlink %b%s%b" $green "$link_name" $rc)"
    if [ "$link_stub" ]; then
        rm -rf "$link_stub"
        success_or_none $? "remove" "$(printf "stub file for %b%s%b" $green "$link_name" $rc)"
    fi
  fi

  # Skip symlink (DRY RUN)
  if [ "$action" == "skip" ]; then

    local skip_reason="skipped "
    if ! dry_run; then
        skip_reason="$DRY_RUN"
    fi

    if ! [ -f "$backup" ];then backup="none";fi

    success "$(printf "Unlink %s for %b%s's %s%b
                      $spacer %bexisting $type%b : $link_file
                      $spacer %blinked to%b : $link_target
                      $spacer %bbackup $type%b : $backup"  \
                      "$skip_reason" $green "$topic" "$link_name" $rc \
                      $green $rc \
                      $green $rc \
                      $green $rc)"

  # Restore backup
  elif [ "$action" == "original" ]; then
    restore_backup_file "$link_file"
    success_or_fail $? "restore" "$(printf "backed up version of %b%s%b" $green "$link_name" $rc)"

  # Keep a copy of repo version
  elif [ "$action" == "repo" ]; then
    if [ -f "$link_target" ]; then
        cp "$link_target" "$link_file"
        success_or_fail $? "copy" "$(printf "repo version of %b%s%b" $green "$link_name" $rc)"
    fi
  fi

  return $?
}


# Requires local topic var
# converts symlink src path to symlink target path
get_symlink_dst () {
    local src_file="$1"
    local dst_path="$2"
    local link_cfg="$(get_topic_config_val "$topic" "symlinks")"
    local src_name
    local alt_name
    local base_name="$(basename "$src_file")"

    if ! [ "$dst_path" ]; then
        dst_path="$(user_home_dir)"
    fi

    #remove extensions
    base_name="${base_name%.symlink}"
    base_name="${base_name%.stub}"

    # create dst path+file name
    dst_file="$dst_path/.$base_name"

    #debug "-- get_symlink_dst: $src_file -> $dst_file"

    # check topic config for symlink paths
    for link in $link_cfg; do
      src_name="$(basename "$src_file")"
      alt_name="${link%-\>*}"
      #debug "(${src_name}=${alt_name})"
      # return config path if found
      if [ "$src_name" = "$alt_name" ]; then
         dst_file="${link#*-\>}"
         #debug "  CONFIG DEST: ($dst_file)"
         mkdir -p "$(dirname "$dst_file")"
         break
      fi
    done

    # return original or new
    echo "$dst_file"
}

# Restores a backup
restore_backup_file(){
  local file="$1"
  local backup="${dst}.dsbak"
  if [ -f "$backup" ];then
    rm -rf "$file"
    mv "$backup" "$file"
    return 0
  fi
  return 1
}


#TODO: manage_topic_bin needs to be incorporated into main or symlink process? also needs freeze
manage_topic_bin () {

    local action="$1"
    local topic="$2"

    local src_bin
    local dst_bin

    if [ "$topic" = "dotsys" ]; then
        src_bin="$(dotsys_dir)/bin}"
        dst_bin="${PLATFORM_USER_BIN}/"

    else
        src_bin="$(topic_dir "$topic")/bin}"
        dst_bin="$(dotsys_user_bin)}"
    fi

    if ! [ -d "$src_bin" ]; then return;fi

    usage="link_topic_bin [<option>]"
    usage_full="
    -s | --silent        Suppress command already exists warning
    "
    local silent

    while [[ $# > 0 ]]; do
        case "$1" in
        -s | --silent )      silent="$1" ;;
        *)  invalid_option ;;
        esac
        shift
    done

    # search for files in topic bin and link/unlink
    local files=("$(find "$src_bin" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')")
    local file
    while IFS=$'\n' read -r file; do
        local command="$(basename "$file")"
        if ! [ "$silent" ] && cmd_exists $command; then
            warn "The command '$command' already exists"
            get_user_input "Are you sure you want to supersede it with
                    $spacer $file?"
            if ! [ $? -eq 0 ]; then return 0;fi
        fi

        if [ "$action" = "upgrade" ]; then
            #symlink "$file" "$dst_bin"
            pass

        elif [ "$action" = "update" ]; then
            #symlink "$file" "$dst_bin"
            pass

        elif [ "$action" = "freeze" ]; then
            freeze_msg "bin" "$file"
            return

        elif [ "$action" = "install" ]; then
            symlink "$file" "$dst_bin"

        elif [ "$action" = "uninstall" ]; then
            unlink "$file"

        fi
    done <<< "$files"
}





