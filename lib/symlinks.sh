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

  local files
  local dst_path

  debug "-- symlink_topic $action $topic SYMLINK_CONFIRMED=$SYMLINK_CONFIRMED"

  # Symlink all files in topic/bin to dotsys/user/bin
  local silent
  if [ "$SYMLINK_CONFIRMED" ]; then silent="--silent";fi

  manage_topic_bin "$action" "$topic" "$silent"

  # find stubs first
  files=( $(get_user_or_builtin_file "$topic" "*.stub") )
  # add symlinks
  files+=( $(get_user_or_builtin_file "$topic" "*.symlink") )

  debug "   symlinks  : $files"

  local linked=()
  local src
  local dst
  local dst_name
  for src in "${files[@]}";do

    debug "   symlink_topic src  : $src"

    # No simlinks found
    if [[ -z "$src" ]]; then
#      if [ "$action" != "freeze" ]; then
#        #success "$(printf "No symlinks required %s for %b%s%b" "$DRY_RUN" $light_green $topic $rc )"
#      fi
      debug "   symlink_topic src  ABORT no symlinks required: $src"
      continue
    fi

    # check for alternate dst in config  *.symlink -> path/name
    dst="$(get_symlink_dst "$src" "$dst_path")"
    dst_name="$(basename "$dst")"

    # Convert stub src path to dotsys/user/stubs
    if is_stub_file "$src";then
        src="$(get_user_stub_file "$topic" "$src")"
    fi

    # Check if stub was already linked
    if [[ "${linked[@]}" =~ "$dst_name" ]]; then
        debug "   symlink_topic ABORT stub already ${action#e}ed"
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

  local type="$(path_type "$src")"
  local dst_target="$(drealpath "$dst")"
  local dst_name="$(basename "$dst")"
  local message
  local options
  local default="repo"

  # Set default for confirmed
  if [ "$SYMLINK_CONFIRMED" = "default" ]; then SYMLINK_CONFIRMED="$default";fi
  local confirmed="$SYMLINK_CONFIRMED"

  debug "-- symlink src   = $src"
  debug "   symlink dst  -> $dst"
  debug "   symlink dtrg -> $dst_target"


  src="$(drealpath "$src")"
  #stub="$(drealpath "${src%.*}.stub")"

  # target path matches source (do nothing)
  if [ -L "$dst"  ] && [ "$dst_target" = "$src" ]; then
      success "Already linked $DRY_RUN" "$(printf "%b$type" $thc )" "$(printf "%b$dst" $thc )"
      return
  fi

  local repo_existing="$src"    # topic/file.symlink or none
  local repo_target="$src"      # topic/file.symlink or file.dsbak or none
  local dst_existing            # existing file at destination
  local stub_file               # src is a stub file

  # Test for existing original
  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]; then
    # not a link, so exits
    if ! [ -L "$dst" ] && ! is_stub_file "$src"; then
      dst_existing="$dst"

    # exists only if dst target exists
    elif [ -f "$dst_target" ]; then
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

  # Get confirmation if file already exists and not confirmed
  if [ "$dst_existing" ] && [ ! "$confirmed" ]; then

    message="$(printf "An existing original version of %b$dst_name%b was found:
               $spacer your repo version: %b${repo_existing:-import existing origianl}%b
               $spacer existing original: %b$dst_existing%b
               $spacer Which version would you like to use?
               $spacer %b(Don't stress, we'll backup any original files)%b" \
               $uhc $uc $yellow $uc $yellow $uc $l_blue $rc)"

    options="$(printf "\n$spacer (%br%b)repo, (%bR%b)all, (%bo%b)original, (%bO%b)all (%bs%b)kip, (%bS%b)all [%b$default%b] : " \
               $green $rc $green $rc $yellow $rc $yellow $rc $blue $rc $blue $rc $dvc $rc)"

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
            S | Skip )SYMLINK_CONFIRMED=skip; break;;
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

  local result
  if [ "$action" == "skip" ]; then

    success "$(printf "Symlink %s for %b%s%b:" "$skip_reason" $thc "$dst_name" $rc)"
    # incorrect link
    if [ -L "$dst" ]; then
      warn "$(printf "Symlinked $type : %b%s%b
                      $spacer currently linked to : %b%s%b
                      $spacer should be linked to : %b%s%b" $thc "$dst" $rc $thc "$dst_target" $rc $thc "$src" $rc)"
    # original file not linked
    elif [ "$dst_existing" ] && [ "$dst_target" = "$dst" ]; then
      warn "$(printf "original $type : %b%s%b
                      $spacer should be linked to : %b%s%b" $thc "$dst" $rc $thc "$src" $rc)"

    # dest not exist
    else
      warn "$(printf "No $type found at: %b%s%b
                      $spacer should be linked to : %b%s%b" $thc "$dst" $rc $thc "$src" $rc)"

    fi

  # keep repo version
  elif [ "$action" == "repo" ] && [ "$dst_existing" ]; then

    # copy existing to repo
    if ! [ "$repo_existing" ] && [ "$repo_target" ];then
        local target_dir="$(dirname "$repo_target")"
        result=$?
        if ! [ -d "$target_dir" ]; then
            mkdir "$(dirname "$repo_target")"
            result=$?
        fi

        if [ $result -eq 0 ];then
            cp "$dst_existing" "$repo_target"
            result=$?
        fi
        success_or_fail $result "move" "original to $repo_target"
    fi

    # backup existing version
    remove_and_backup_file "original" "$dst_existing"

  # keep original version
  elif [ "$action" == "original" ] && [ "$dst_existing" ]; then

    # backup repo version
    if [ "$repo_existing" ];then
        remove_and_backup_file "repo" "$repo_existing"
    fi

    # move existing to repo
    mv "$dst_existing" "$repo_target"
    success_or_fail $? "move" "original to $repo_target"
  fi

  # Always link the source to dst unless skipped
  if [ "$action" != "skip" ]; then
    # Create native symlinks on Windows.
    export CYGWIN=winsymlinks:nativestrict
    ln -fs "$src" "$dst"

    if [ "$stub_file" ]; then
        stub_file="\n$spacer stub -> $stub_file"
    fi

    if [ "$repo_target" ]; then
        repo_target="\n$spacer repo -> $repo_target"
    fi

    success_or_fail $? "link" "$type" "$(printf "%b$dst" $thc)" "$stub_file" "$repo_target"
  fi
}

remove_and_backup_file(){
  local desc="$1"
  local file="$2"
  local backup="${file}.dsbak"

  if ! [ -f "$backup" ] ; then
      mv "$file" "$backup"
      success_or_fail $? "back" "up $desc version of" "$(printf "%b$file" $thc)" "\n$spacer new backup ->" "$(printf "%b$backup" $thc)"
  else
      rm -rf "$file"
      success_or_fail $? "remove" "$desc version of" "$(printf "%b$file" $thc)" "\n$spacer existing backup ->" "$(printf "%b$backup" $thc)"
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

  if ! [ "$SYMLINK_CONFIRMED" ]; then

      # No original file exists
      if ! [ -f "$backup" ]; then

          # repo has original file
          if [ -f "$link_target" ]; then
              get_user_input "No backup of $link_name was found,
                      $spacer keep a copy of the repo version?" \
                      --true "repo" --false "none" --confvar "SYMLINK_CONFIRMED" --required --clear
              if [ $? -eq 0 ]; then action=repo ;fi
          fi

      # original file & repo file exist (not stub)
      elif [ -f "$link_target" ]; then

        local default="original"

        message="$(printf "Two versions of the $type %b%s%b were found:
                $spacer %boriginal backup%b : $backup
                $spacer %bcurrent repo%b : $link_target
                $spacer Which version of the file would you like to keep?
                $spacer (%bo%b)riginal, (%bO%b)all, (%br%b)epo, (%bR%b)all, (%bn%b)one, (%bN%b)all [%b$default%b]: " \
                $uhc "$link_name" $uc \
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

      # no file available to keep
      else
        action=none
      fi



  fi

  action=${action:-$SYMLINK_CONFIRMED}

  debug "-- unlink final action = $action"


  if [ "$action" != "skip" ]; then
    # Remove the symlink
    rm -rf "$link_file"
    success_or_none $? "remove" "$type for" "$(printf "%b$topic's $link_name" $thc )"
  fi

  # Skip symlink (DRY RUN)
  if [ "$action" == "skip" ]; then

    local skip_reason="skipped "
    if ! dry_run; then
        skip_reason="$DRY_RUN"
    fi

    if ! [ -f "$backup" ];then backup="none";fi

    success "Unlink $skip_reason for" "$(printf "%b$topic's $link_name" $thc)" "
     $spacer existing $type : $link_file
     $spacer linked to $type: $link_target
     $spacer backup $type%  : $backup"

  # Restore backup
  elif [ "$action" == "original" ]; then
    restore_backup_file "$link_file"
    success_or_none $? "restore" "backed up version of" "$(printf "%b$topic's $link_name" $thc )"

  # Keep a copy of repo version
  elif [ "$action" == "repo" ]; then
    if [ -f "$link_target" ]; then
        cp "$link_target" "$link_file"
        success_or_fail $? "copy" "repo version of" "$(printf "%b$topic's $link_name" $thc )"
    fi
  fi

  return $?
}


# Requires local topic var
# converts symlink src path to symlink target path
get_symlink_dst () {
    local src_file="$1"
    local dst_path="$2"
    local symlink_cfg="$(get_topic_config_val "$topic" "symlinks")"
    local cfg_name
    local src_name="$(basename "$src_file")"
    src_name="${src_name%.symlink}"
    src_name="${src_name%.${topic}.stub}"
    src_name="${src_name%.stub}"
    src_name="${src_name%.vars}"
    src_name="${src_name%.sources}"

    if ! [ "$dst_path" ]; then
        dst_path="$(platform_user_home)"
    fi

    # create dst path+file name
    dst_file="$dst_path/.$src_name"

    #debug "-- get_symlink_dst: $src_file -> $dst_file"

    # check topic config for symlink paths
    for cfg in $symlink_cfg; do
      cfg_name="${cfg%-\>*}"
      #debug "(${src_name}=${cfg_src})"
      # return config path if found
      if [ "$src_name" = "$cfg_name" ]; then
         dst_file="${cfg#*-\>}"
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
  local backup="${file}.dsbak"
  if [ -f "$backup" ];then
    mv "$backup" "$file"
    return 0
  fi
  return 1
}


manage_topic_bin () {

    local action="$1"
    local topic="$2"

    local src
    local src_bin
    local dst_bin

    if [ "$topic" = "core" ]; then
        src="$(dotsys_dir)"
        dst_bin="${PLATFORM_USER_BIN}"
    else
        # topic_dir is not guaranteed
        src="$(topic_dir "$topic")"
        dst_bin="$(dotsys_user_bin)"
    fi

    src_bin="$src/bin"

    if ! [ -d "$src" ] || ! [ -d "$src_bin" ]; then
        return
    fi

    local usage="link_topic_bin [<option>]"
    local usage_full="
    -s | --silent        Suppress command already exists warning
    "
    local silent

    while [[ $# > 0 ]]; do
        case "$1" in
        -s | --silent )      silent="true" ;;
        *)  invalid_option ;;
        esac
        shift
    done

    debug "-- manage_topic_bin: $action $topic $silent"
    debug "   manage_topic_bin src_bin : $src_bin"
    debug "   manage_topic_bin dst_bin : $dst_bin"

    # search for files in topic bin and link/unlink
    local files=("$(find "$src_bin" -mindepth 1 -maxdepth 1 -type f -not -name '\.*')")
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
             \r     -> $dst_file"

        if [ "$action" = "upgrade" ]; then
            #symlink "$file" "$dst_bin"
            # currently not required since all symlinks
            pass

        elif [ "$action" = "update" ]; then
            #symlink "$file" "$dst_bin"
            # currently not required since all symlinks
            pass

        elif [ "$action" = "freeze" ]; then
            freeze_msg "bin" "$file"
            return

        elif [ "$action" = "link" ]; then
            chmod u+x "$file"
            symlink "$file" "$dst_file"

        elif [ "$action" = "unlink" ]; then
            unlink "$dst_file"

        fi
    done <<< "$files"
}





