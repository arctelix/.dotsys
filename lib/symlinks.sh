#!/bin/bash

import dsman manage_topic_dsm

# Symlink functions
# Author: arctelix

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

  # Capture action
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

  local links

  debug "-- symlink_topic $action $topic SYMLINK_CONFIRMED=$SYMLINK_CONFIRMED"

  # Symlink all files in topic/bin to dotsys/user/bin
  local silent
  if [ "$SYMLINK_CONFIRMED" ]; then silent="--silent";fi

  manage_topic_bin "$action" "$topic" "$silent"

  if [ "$topic" = "bin" ]; then return;fi

  # find stubs first (files only)
  links=( $(get_user_or_builtin f "$topic" "*.stub") )
  # add symlinks (files & dirs)
  links+=( $(get_user_or_builtin a "$topic" "*.symlink") )

  debug "   symlinks  : $links"

  local linked=()
  local src
  local dst
  local dst_name
  for src in ${links[@]};do

    debug "   symlink_topic src  : $src"

    # No symlinks found
    if [[ -z "$src" ]]; then
      debug "   symlink_topic src  ABORT no symlinks required: $src"
      continue
    fi

    # All destination changes must be made in get_symlink_dst
    # so that stubs get same destination
    dst="$(get_symlink_dst "$src" )"
    dst_name="$(basename "$dst")"

    # Convert src path to dotsys/user/stubs for stub files
    if is_stub_file "$src";then
        src="$(get_user_stub_file "$topic" "$src")"
    fi

    # Check if stub was already linked
    if [[ "${linked[@]}" =~ "$dst_name" ]]; then
        debug "   symlink_topic ABORT stub already ${action#e}ed for $dst_name"
        continue
    fi
    linked+=("$dst_name")

    debug "   symlink_topic dts : $dst"

    if [ "$action" = "link" ] ; then
      symlink "$src" "$dst"

    elif [ "$action" = "unlink" ]; then
      # Do not allow stub file links to be removed if dotsys requires it
      if [[ "$src" =~ .stub ]] && is_required_stub; then
        debug "   symlink_topic: ABORT unlink (stub required by dotsys) $src"
        continue
      fi
      unlink "$dst"

    elif [ "$action" = "upgrade" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "update" ]; then
      symlink "$src" "$dst"

    elif [ "$action" = "freeze" ]; then
      if [ "$(drealpath "$dst")" == "$src" ]; then
        freeze_msg "symlink" "$dst \n$spacer -> $src"
      fi
    fi

  done
}


# symLinks a single file
symlink () {

  local usage="symlink [<action>] <source> <destination>"
  local usage_full="
  Options
    -d | default  Use default (repo)
    -o | original Use the original version found on system
    -r | repo     Use the repo version if original version is found
    -n | none     Do not use repo or existing version
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
      -d | default )    SYMLINK_CONFIRMED=repo ;;
      -o | original )   SYMLINK_CONFIRMED=original ;;
      -r | repo )       SYMLINK_CONFIRMED=repo ;;
      -s | skip )       SYMLINK_CONFIRMED=skip ;;
      -n | none )       SYMLINK_CONFIRMED=none ;;
      dryrun )          SYMLINK_CONFIRMED=skip ;;
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
  local dst_target="$(drealpath "$dst")"
  local dst_name="$(basename "$dst")"
  local message
  local options
  local default="repo"


  if [ "$SYMLINK_CONFIRMED" ]; then
      # Set default for confirmed
      if [ "$SYMLINK_CONFIRMED" = "default" ]; then
        SYMLINK_CONFIRMED="$default"
        SYMLINK_NOREPO="$default"
      else
        SYMLINK_NOREPO="$SYMLINK_CONFIRMED"
      fi
  else
      SYMLINK_CONFIRMED="$(config_symlink_option)"
      if [ "$SYMLINK_CONFIRMED" = "confirm" ]; then SYMLINK_CONFIRMED="";fi
      SYMLINK_NOREPO="${SYMLINK_NOREPO:-$(config_symlink_norepo)}"
      if [ "$SYMLINK_NOREPO" = "confirm" ]; then SYMLINK_NOREPO="";fi
  fi

  debug "-- symlink src   = $src"
  debug "   symlink dst  -> $dst"
  debug "   symlink dtrg -> $dst_target"

  src="$(drealpath "$src")"
  #stub="$(drealpath "${src%.*}.stub")"

  # target path matches source (do nothing)
  if [ -L "$dst"  ] && [ "$dst_target" = "$src" ]; then
      success "Already linked $DRY_RUN" "$(printf "%b$type" "$hc_topic" )" "$(printf "%b$dst" "$hc_topic" )"
      return
  fi

  local repo_existing="$src"    # topic/file.symlink or none
  local repo_target="$src"      # topic/file.symlink or file.dsbak or none
  local dst_existing            # existing file at destination
  local stub_file               # src is a stub file

  # Test for existing original
  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]; then
    # not a link, so its an exiting file
    if ! [ -L "$dst" ]; then
      dst_existing="$dst"

    # exists only if dst target exists and target is not .stub or .symlink
    elif [ -f "$dst_target" ] && ! is_symlinked "$dst_target"; then
      dst_existing="$dst"
    fi
  fi

  debug "   dst_existing = $dst_existing"

  # check if src is a stub file
  if is_stub_file "$src";then
    stub_file="$src"
    repo_target="$(get_user_stub_target "$stub_file")"
    repo_existing="$(get_user_stub_target "$stub_file" "user")"
  fi

  debug "   repo_existing = $repo_existing"
  debug "   repo_target = $repo_target"

  # existing and no repo version (import mode)
  if [ "$dst_existing" ] && ! [ "$repo_existing" ]; then

   # confirm options with user
    if ! [ "$SYMLINK_NOREPO" ]; then
        get_user_input "Do you want to import the existing original $dst_name $type
                $spacer from your home directory or just use the repo stub file?" \
                --true "original" --false "repo" -r -v SYMLINK_NOREPO --clear
        if [ $? -eq 0 ]; then
            action="original"
        fi
    else
        action="$SYMLINK_NOREPO"
    fi

  # existing and repo version found
  elif [ "$dst_existing" ] && [ ! "$SYMLINK_CONFIRMED" ]; then

    message="$(printf "An existing original version of %b$dst_name%b was found:
               $spacer your repo version: %b$repo_existing%b
               $spacer existing original: %b$dst_existing%b
               $spacer Which version would you like to use?
               $spacer %b(Don't stress, we'll backup any original files)%b" \
               $hc_user $c_user $yellow $c_user $yellow $c_user $l_blue $rc)"

    options="$(printf "\n$spacer (%br%b)repo, (%bR%b)all, (%bo%b)original, (%bO%b)all (%bs%b)kip, (%bS%b)all [%b$default%b] : " \
               $green $rc $green $rc $yellow $rc $yellow $rc $blue $rc $blue $rc $c_default $rc)"

    user "$message $options"

    while true; do
        # Read from tty, needed because we read in outer loop.
        read user_input < /dev/tty

        case "$user_input" in
            o | original )action=original; break;;
            O | Original )SYMLINK_CONFIRMED=original; break;;
            r | repo )action=repo; break;;
            R | Repo )SYMLINK_CONFIRMED=repo; break;;
            s | skip )action=skip; break;;
            S | skip )SYMLINK_CONFIRMED=skip; break;;
            "") action="$default"; break;;
            * ) msg_invalid_input "$message > invalid '$user_input': "
            ;;
        esac
    done

    clear_lines "$message" ${clear:-0}

  fi

  action=${action:-$SYMLINK_CONFIRMED}

  debug "-- symlink confirmed action: $action
       \r   src : $src
       \r   dst : $dst"

  local skip_reason="skipped "
  if dry_run; then
      skip_reason="$DRY_RUN"
  fi

  local result=0


  if [ "$action" == "skip" ]; then

    success "$(printf "Symlink %s for %b%s%b:" "$skip_reason" "$hc_topic" "$dst_name" $rc)"
    # incorrect link
    if [ -L "$dst" ]; then
      warn "$(printf "Symlinked $type : %b%s%b
                      $spacer currently linked to : %b%s%b
                      $spacer should be linked to : %b%s%b" "$hc_topic" "$dst" $rc "$hc_topic" "$dst_target" $rc "$hc_topic" "$src" $rc)"
    # original file not linked
    elif [ "$dst_existing" ] && [ "$dst_target" = "$dst" ]; then
      warn "$(printf "original $type : %b%s%b
                      $spacer should be linked to : %b%s%b" "$hc_topic" "$dst" $rc "$hc_topic" "$src" $rc)"

    # dest not exist
    else
      warn "$(printf "No $type found at: %b%s%b
                      $spacer should be linked to : %b%s%b" "$hc_topic" "$dst" $rc "$hc_topic" "$src" $rc)"

    fi

  # use repo version
  elif [[ "$action" = "repo" || "$action" = "none" ]]  && [ "$dst_existing" ]; then

    # backup existing version
    remove_and_backup_file "original" "$dst_existing"

  # import original version to repo
  elif [ "$action" == "original" ] && [ "$dst_existing" ]; then

    # backup repo version (disable it)
    if [ "$repo_existing" ];then
        remove_and_backup_file "repo" "$repo_existing"
    fi

    # Confirm repo target & move existing
    if [ "$repo_target" ]; then

        # make sure target directory exists
        local target_dir="$(dirname "$repo_target")"
        if ! [ -d "$target_dir" ]; then
            mkdir "target_dir"
            result=$?
            success_or_fail $result "create" "directory $target_dir"
        fi

        # Copy existing to repo target
        if [ $result -eq 0 ];then
            cp "$dst_existing" "$repo_target"
            result=$?
            success_or_fail $result "copy" "original to $repo_target"
        fi

        # keep a backup copy of original in original location
        if [ $result -eq 0 ];then
            remove_and_backup_file "original" "$dst_existing"
        fi
    fi

    if [ $result -eq 0 ];then
        success "Original existing $dst_name $type imported to repo"
    else
        success "Original existing $dst_name $type left in place"
        action="none"
    fi
  fi

  # Always link the source to dst unless skipped
  if [ "$action" != "skip" ] && [ "$action" != "none" ]; then

    export CYGWIN=winsymlinks:nativestrict
    dsudo ln -fs "$src" "$dst"
    result=$?

    if [ "$stub_file" ]; then
        stub_file="\n$spacer stub file -> $stub_file"
    fi

    if [ "$repo_target" ]; then
        repo_target="\n$spacer user file -> $repo_target"
    fi

    success_or_fail $result "link" "$type" "$(printf "%b$dst" "$hc_topic")" "$stub_file" "$repo_target"
  fi
}

remove_and_backup_file(){
  local desc="$1"
  local file="$2"
  local backup="${file}.dsbak"

  if ! [ -f "$backup" ] ; then
      dsudo mv "$file" "$backup"
      success_or_fail $? "back" "up $desc version of" "$(printf "%b$file" "$hc_topic")" "\n$spacer new backup ->" "$(printf "%b$backup" "$hc_topic")"
  else
      dsudo rm -rf "$file"
      success_or_fail $? "remove" "$desc version of" "$(printf "%b$file" "$hc_topic")" "\n$spacer existing backup ->" "$(printf "%b$backup" "$hc_topic")"
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
  local confirmed="$(config_unlink_option)"
  if [ "$confirmed" = "confirm" ]; then confirmed="";fi
  local confirmed_nobackup="$(config_unlink_nobackup)"
  if [ "$confirmed_nobackup" = "confirm" ]; then confirmed_nobackup="";fi

  # File does not exits
  if [ ! -f "$link_file" ] && [ ! -L "$link_file" ]; then
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
  local message

  # We care about the .symlink not the .stub!
  if is_stub_file "$link_target" ]; then
        link_stub="$link_target"
        link_target="${link_target%.stub}.symlink"
  fi


  # No original file exists & repo has original file
  if ! [ -f "$backup" ] && [ -f "$link_target" ]; then

      if ! [ "$confirmed_nobackup" ]; then
          get_user_input "No backup of $link_name was found, keep a copy
                  $spacer of the repo version or none?" \
                  --true "none" --false "repo" --confvar "UNLINK_NOBACKUP" --required --clear
          if ! [ $? -eq 0 ]; then action=repo ;fi
      else
          action="$confirmed_nobackup"
      fi

  # original file & repo file exist (not stub)
  elif ! [ "$confirmed" ] && [ -f "$link_target" ]; then

    local default="original"

    message="$(printf "Two versions of the $type %b%s%b were found:
            $spacer %boriginal backup%b : $backup
            $spacer %bcurrent repo%b : $link_target
            $spacer Which version of the file would you like to keep?
            $spacer (%bo%b)riginal, (%bO%b)all, (%br%b)epo, (%bR%b)all, (%bn%b)one, (%bN%b)all [%b$default%b]: " \
            $hc_user "$link_name" $c_user \
            $green $rc \
            $yellow $rc \
            $green $rc $green $rc \
            $yellow $rc $yellow $rc \
            $blue $rc $blue $rc \
            $dark_gray $rc)"

    user "$message"

    while true; do
      # Read from tty, needed because we read in outer loop.
      read user_input < /dev/tty

      case "$user_input" in
        o | original )action=original; break;;
        O | Original )SYMLINK_CONFIRMED=original; break;;
        r | repo )action=repo; break;;
        R | Repo )SYMLINK_CONFIRMED=repo; break;;
        n | none )action=none;break ;;
        N | None )SYMLINK_CONFIRMED=none; break ;;
        "") action="$default"; break ;;
        * ) msg_invalid_input "$message invalid entry '$user_input' : "
          ;;
      esac
    done

    clear_lines "$message" ${clear:-0}

  # Restore the backup
  elif [ -f "$backup" ]; then
    action=original

  # no file available to keep
  else
    action=none
  fi


  action=${action:-$SYMLINK_CONFIRMED}

  debug "-- unlink final action = $action"


  if [ "$action" != "skip" ]; then
    # Remove the symlink
    dsudo rm -rf "$link_file"
    success_or_none $? "remove" "$type for" "$(printf "%b$topic's $link_name" "$hc_topic" )"
  fi

  # Skip symlink (DRY RUN)
  if [ "$action" == "skip" ]; then

    local skip_reason="skipped "
    if ! dry_run; then
        skip_reason="$DRY_RUN"
    fi

    if ! [ -f "$backup" ];then backup="none";fi

    success "Unlink $skip_reason for" "$(printf "%b$topic's $link_name" "$hc_topic")" "
     $spacer existing $type : $link_file
     $spacer linked to $type: $link_target
     $spacer backup $type%  : $backup"

  # Restore backup
  elif [ "$action" == "original" ]; then
    restore_backup_file "$link_file"
    success_or_none $? "restore" "backed up version of" "$(printf "%b$topic's $link_name" "$hc_topic" )"

  # Keep a copy of repo version
  elif [ "$action" == "repo" ]; then
    if [ -f "$link_target" ]; then
        cp "$link_target" "$link_file"
        success_or_fail $? "copy" "repo version of" "$(printf "%b$topic's $link_name" "$hc_topic" )"
    fi
  fi

  return $?
}


# Requires local topic var
# converts symlink src path to symlink target path
get_symlink_dst () {
    local src_file="$1"
    local dst_dir
    local repo_dir
    local symlinks_list="$(get_topic_config_val "$topic" "symlinks")"
    local symlink_root="$(get_topic_config_val "$topic" "symlink_root")"
    local symlink_prefix="$(get_topic_config_val "$topic" "symlink_prefix")"
    local cfg_name
    local src_name_o="$(basename "$src_file")"
    local src_name="$src_name_o"
    src_name="${src_name%.symlink}"
    src_name="${src_name%.${topic}.stub}"
    src_name="${src_name%.stub}"
    src_name="${src_name%.vars}"
    src_name="${src_name%.sources}"

    debug "-- get_symlink_dst src: $src"

    # Remove topic directory and src_name from src_file path
    # repo_dir preserves repo directory structure
    if [ "$src_name_o" != "${src_name_o%.symlink}" ]; then
        repo_dir="${src_file#$(topic_dir "$topic")/}"
        repo_dir="${repo_dir%/$src_name_o}"
        repo_dir="${repo_dir%$src_name_o}"
        debug "   get_symlink_dst repo_dir = $repo_dir"
    fi


    # symlink_dir overrides default
    if [ "$symlink_root" ]; then
        dst_dir="$symlink_root"

    # Default root is user home
    else
        dst_dir="$(platform_user_home)"
    fi

    # Default prefix is "." use none for ""
    if [ "$symlink_prefix" = "none" ]; then
        symlink_prefix=''
    elif ! [ "$symlink_prefix" ]; then
        symlink_prefix='.'
    fi

    # Prefix repo dir
    if [ "$repo_dir" ];then
        dst_dir="$dst_dir/${symlink_prefix}${repo_dir}"
        dst_file="${dst_dir}/${src_name}"

    # Prefix file
    else
        dst_file="${dst_dir}/${symlink_prefix}${src_name}"
    fi

    # symlinks_list files override all
    for cfg in $symlinks_list; do
      cfg_name="${cfg%-\>*}"

      # return config path if found
      if [ "$src_name" = "$cfg_name" ]; then
         dst_file="${cfg#*-\>}"
         dst_dir="$(dirname "$dst_file")"
         debug "  CONFIG DEST: ($dst_file)"
         break
      fi
    done

    if ! [ -d "$$dst_dir" ]; then
        mkdir -p "$dst_dir"
    fi

    debug "   dest = $dst_file"

    echo "$dst_file"
}

# Restores a backup
restore_backup_file(){
  local file="$1"
  local backup="${file}.dsbak"
  if [ -f "$backup" ];then
    dsudo mv "$backup" "$file"
    return 0
  fi
  return 1
}


manage_topic_bin () {

    local action="$1"
    local topic="$2"
    shift; shift

    local src
    local src_bin
    local dst_bin

    if [ "$topic" = "dotsys" ]; then
        src="$(dotsys_dir)"
        dst_bin="${PLATFORM_USER_BIN}"
        src_bin="$src/bin"

    elif [ "$topic" = "bin" ]; then
        src="$(topic_dir "$topic")"
        dst_bin="$(dotsys_user_bin)"
        src_bin="$src"

    else
        # topic_dir is not guaranteed
        src="$(topic_dir "$topic")"
        dst_bin="$(dotsys_user_bin)"
        src_bin="$src/bin"
    fi

    if ! [ -d "$src" ] || ! [ -d "$src_bin" ]; then
        return
    fi

    local usage="manage_topic_bin [<option>]"
    local usage_full="
    -s | --silent        Suppress command already exists warning
    "
    local silent

    while [[ $# > 0 ]]; do
        case "$1" in
        -s | --silent )      silent="true" ;;
        *)  invalid_option "$1";;
        esac
        shift
    done

    debug "-- manage_topic_bin: $action $topic $silent"
    debug "   manage_topic_bin src_bin : $src_bin"
    debug "   manage_topic_bin dst_bin : $dst_bin"

    # search for files in topic bin and link/unlink
    local files=("$(find -L "$src_bin" -mindepth 1 -maxdepth 1 -not -name '\.*' -a -not -name '*.dsm')")
    local file
    while IFS=$'\n ' read -r file; do

        # test for exitsing command
        local command="$(basename "$file")"
        if ! [ "$topic" = "core" ] && ! [ "$silent" ] && [ "$action" = "install" ] && cmd_exists $command; then
            warn "The command '$command' already exists on the system path"
            get_user_input "Are you sure you want to supersede it with
                    $spacer $file?" --required
            if ! [ $? -eq 0 ]; then return 0;fi
        fi

        local dst_file="${dst_bin}/$(basename "$file")"

        debug "   - manage_topic_bin: $action $topic file: $file
             \r      -> $dst_file"

        if [ "$action" = "freeze" ]; then
            freeze_msg "bin" "$file"
            return

        elif [ "$action" != "unlink" ] && ! [ -L "$dst_file" ]; then
            chmod 755 "$file"
            symlink "$file" "$dst_file"

        elif [ "$action" = "unlink" ]; then
            unlink "$dst_file"

        fi
    done <<< "$files"
}

is_symlinked () {
    [ "$1" != "${1%.stub}" ] || [ "$1" != "${1%.symlink}" ]
}