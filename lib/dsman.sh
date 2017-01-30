#!/usr/bin/env bash
. $DOTSYS_LIBRARY/core.sh
import github
import bitbucket
import state get_state_value
import state set_state_value
import state in_state
import output compile_text
import output indent_lines

STATE_NAME='dsman'
indent="  "
spacer="\r       "
set -o pipefail


if [ -d "$DOTSYS_REPOSITORY" ];then
    DSM_DIR="$DOTSYS_REPOSITORY/user/dsm"
else
    DSM_DIR="~/.dsm"
fi

#TODO: Add dsm key word into dotsys syntax like cmd and app
#      - dotsys <action> dsm .....
#TODO: Maybe we should separate dsm from dotsys completely?
#      - Move dsm.state file to DSM_DIR
#      - Remove dotsys imports (it's mostly overkill for dsm needs)
#        OR use dsm to download the required dotsys files!!!!!!!!!!

dsman () {

    local usage="dsm <action> <pkg_name> [-h,--help] [--force]

    install [<name>] <endpoint> [<user>/]<repo> [<version>] [<file>] [<options>]

    install [<name>] <full url to raw download> [<version>] [<file>] [<options>]

    install options :

        [-v, --version] [-f, --file] [-d, -destination] [-i, --ignore]
    "

    local usage_full="
    Dotsys Manager (dsm) is a simple bash package manager allowing you to
    use any url to a file in raw, zip, or tar.gz format as as a package.

    Ideally, your using urls to git repositories that use the standard
    raw file and archive structure. An endpoint syntax may be used for
    commonly used sources such as github and bitbucket.

    NOTE: Python is required to parse the 'latest' git tags, otherwise
    'master' will be used as the latest version.

    Actions:
        install         Install a new package (requires url or endpoint)
        uninstall       Uninstall a package
        upgrade         Upgrade a package version
        update          Update dotsys manager index
        version         Get installed version of package
        list            List installed packages
        create          create a repository and or file

    Options:
        --force         Force an action to run again
        -h | --help     Show this help message

    INSTALLING PACKAGES:

        Installing new packages requires an endpoint or url to download a
        file or archive from.  Once installed you can refer to it by it's
        package name.  When no file is specified the entire repo will be
        downloaded.

        name            A package name to refer to the file or archive.
                        If omitted, default names will be used as follows:
                        archive urls & endpoints    : <user>_<repo>
                        file urls & endpoints       : <repo>_<file>_<ext>
                        dotsys <filename>.dsm       : <filename>
                        dotsys dsm managed topics   : <topic>

        endpoint        A short hand supported popular git end pints.
                        A repo is required when using an endpoint.
                        gh | github
                        bb | bitbucket

        user/repo       Required for endpoints. If no file is specified
                        a repo archive will be downloaded. Omit 'user/'
                        to use your git config user.name.

        url             A full url to a raw file or archive file download.

        version         Most git endpoints permit, tags, branches, and commits.
                        Specify 'latest' or omit the version to get the
                        latest tagged release or the current master branch
                        note: python is required for latest release

        file            Specify a specific file from the repository to download.
                        omit: get repository archive file

    Install options:

        -d | --destination  The destination directory for archive or file
        -l | --link         Download to dsm directory and symlink to destination
                            Note: This is the default for all dotsys calls
        -f | --file         Specify a file from repo
        -v | --version      Specify a version for file or archive
        -i | --ignore       Space separated quoted list of files to be
                            ignored in downloaded archive. Patterns are
                            added to defaults.
                            defaults: .gitignore bats *.md docs tests
        -ir| --ignore-r     Same as ignore but replaces defaults

    Other options (must be first arg):
        -a | --auth         Endpoint authentication <user>, <user:pass>
                            use * for git config user.name <*>, <*:pass>
        -t | --topic        Apply action to all dotsys topic .dsm files
                            (must be first and only option)

    Install from endpoint:

        install [<name>] <endpoint> [<user>/]<repo> [<version>] [<file>] [<options>]

        ex: install the latest version of ctool from your cool-tool repo
        > dsm install gh cool-tool master ctool.sh
        > dsm install gh cool-tool -f ctool.sh

        ex: install a tagged version of arctelix's ctool
        > dsm install gh arctelix/cool-tool v0.1.5 ctool.sh

        ex: install the latest version of the cool-tool repo
        > dsm install gh cool-tool v0.1.5

    Install from url:

        install [<name>] <full url to raw download> [<version>] [<file>] [<options>]

        Standard file url: proto://<domain>/<user>/<repo>/<?>/<version>/<file>
        Standard archive url: proto://<domain>/<user>/<repo>/<?>/<version>.<archive>

        If your url varies from the standard format, you must specify <name> and <version>
        When upgrading packages with non standard urls, a full url will be required.
        NOTE: Archive type must be tar.gz or zip.

        ex: Install from a standard url
        > dsm install https://github.com/user/cool-tool/raw/master/ctool.sh

        ex: Install file from a non standard url
        > dsm install cool-tool https://domein.com/files/0.1.5/ctool.sh 0.1.5

        ex: Install archive from a non standard url
        > dsm install cool-tool https://domein.com/files/cool-tool.tar.gz 0.1.5

    state files:

        Two state files are maintained
        dsm.state   : files installed from dotsys.dsm files or 'dsm install' command
        dsman.state : files installed from dotsys topics with dsm as manager or 'dotsys dsm install'
    "


    local force dest pkg_state file_name call_action_func rv state_val archive_type topic link_state
    local action pkg_name endpoint user repo file_path version
    local ignore=(".gitignore" "bats" "README.md" "docs" "tests")

    check_for_help "$1"
    [[ "$1" =~ --debug ]] && DEBUG=true && shift
    action="$1"; shift
    [[ "$1" =~ --debug ]] && DEBUG=true && shift
    call_action_func="_$action"

    debug  "->DSM DEBUG: $@"

    [ "$action" = "update" ] && exit 0

    if ! [[ "$action" =~ ^list|^update|^install|^upgrade|^uninstall|^version ]];then
        [ "$action" ] && error "$action is not a valid action"
        show_usage
        exit 1
    fi

    # remove pkg_name endpoint or url from args
    local ol=$#
    while [[ $# > 0 ]]; do
        case "$1" in
        gh | github )           endpoint="github";;
        bb | bitbucket )        endpoint="bitbucket";;
        http* )                 file_url="$1";;
        esac

        if [ "$endpoint" ]; then
            file_url=false
            endpoint="$endpoint $2"
            shift; shift
            break
        elif [ "$file_url" ];then
            shift
            break
        elif [[ ol -eq $# ]]; then
            pkg_name="$1"
            shift
        else
            break
        fi
    done

    # Make sure pkg is installed
    if [ "$action" != "install" ] && [ "$pkg_name" ] && ! in_state "$STATE_NAME" "$pkg_name";then
        error "Package, $pkg_name, is not installed.
       $spacer Use 'dsm list' for installed package list"
        exit 1
    fi

    # Get exiting values from state
    if [[ ! "$endpoint" && ! "$file_url" ]]; then
        local state_val

        # Check for installed
        IFS=$'\n'
        state_val=( $(echo "$(get_state_value "$STATE_NAME" "$pkg_name")" | xargs -n1 ) )
        unset IFS

        if [ "$state_val" ];then
            dsman $action $pkg_name "${state_val[@]}" "${endpoint:-$file_url}" "$@"
            exit $?

        elif [ "$action" = "install" ]; then
            error "An endpoint or url is required to install
           $spacer a new package. Use 'dsm --help' for details."
            exit 1
        fi
    fi

    debug "  dsm initial parse: $action $pkg_name ${endpoint:-$file_url}"
    local x_version x_file_path x_dest x_ignore

    # remove state values
    while [[ $# > 0 ]]; do
        case "$1" in
        -xv )                   x_version="$2"; shift; shift;;
        -xf )                   x_file_path="$2"; shift; shift;;
        -xd )                   x_dest="$2"; shift; shift;;
        -xl )                   x_link="true"; shift; shift;;
        -xi )                   x_ignore=( $2 ); shift; shift;;
        -a | --auth)            auth="${2}"; shift; shift;;
        -t | --topic)           topic="${2}"; shift; shift;;
        * ) break
        esac
    done

    debug "  state parse: -xv $x_version -xf $x_file_path -xd $x_dest -xi ${x_ignore[*]}"
    debug "  post-state params: $@"

    # parse endpoint or url for vars
    if [ "$endpoint" ];then
        local eps=( $endpoint )
        endpoint_module="${eps[0]}"
        repo="${eps[1]}"
        user="${repo%/*}"
        repo="${repo#*/}"
        [ "$user" == "$repo" ] && user="$(git config user.name)"
        required_vars "action" "endpoint" "user" "repo"

    # Set variables from url
    elif [ "$file_url" ] && [ "$file_url" != false ];then
        parse_url "$file_url"
    fi

    # apply action to topic and exit
    if [ "$topic" ];then
        manage_topic_dsm "$action" "$topic"
        return $?
    fi

    # Stop here for all but install, upgrade, uninstall
    if ! [[ "$action" =~ install|upgrade|uninstall ]];then
        task "${action}" "$pkg_name"
        $call_action_func "$pkg_name" "$@"
        exit $?
    fi

    # install/upgrade/uninstall only below this point

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )               force=true;;
        -d | --destination )    dest="$2"; shift;;
        -l | --link )           link="true"; shift;;
        -i | --ignore )         ! [[ "${ignore[@]}" =~ $2 ]] && ignore+=( $2 ); shift;;
        -f | --file )           file_path="$2"; shift;;
        -v | --version )        version="$2"; shift;;
        --debug )               DEBUG=true;;
        -ir | --ignore-r )      ignore=( $2 ); shift;;
        * ) uncaught_case "$1" "version" "file_path" "dest"
        esac
        shift
    done

    dest="${dest:-$x_dest}"
    link="${link:-$x_link}"
    version="${version:-$x_version}"
    file_path="${file_path:-$file_path}"

    # Check if we're dealing with an archive
    archive_type="$(is_archive "$file_path" -r)"

    # Make sure input dst is absolute
    if [ "$dest" ] && [ "${dest::1}" != '/' ]; then
        dest="${dest#./}"
        dest="$PWD/${dest#.}"
    fi

    #file_path="${file_path:-${version}.tar.gz}"

    local dsm_dest="$DSM_DIR/$user/$repo"

    # Set default pkg_name and dst
    if is_archive; then
        pkg_name="${pkg_name:-${user}_${repo}}"
        dest="${dest:-$PWD/$repo}"
    else
        file_name="${file_path##*/}"
        pkg_name="${pkg_name:-${repo}_${file_name//./_/}}"
        dest="${dest:-$PWD/$file_name}"
        dsm_dst="$dsm_dest/$file_name"
    fi

    local dest_state="$dest"

    # Check for link and modify dest
    if [ "$link" ];then
        link="$dest"
        dest="$dsm_dest"
        link_state="-xl"
        debug "  link found new dest = $dest"
    fi

    # pkg_name is now safe to use !

    local installed
    in_state "dsman" "$pkg_name"
    [ $? -eq 0 ] &&  installed=true

    # Make sure pkg is installed AGAIN! May hve been parsed
    if [ "$action" != "install" ] && ! [ "$installed" ];then
        error "Package, $pkg_name, is not installed.
       $spacer Use 'dsm list' for installed package list"
        exit 1
    fi

    # Endpoint or url+version required at this point
    if ! [ "$endpoint" ] && [[ ! "$version" || ! "$file_url" ]];then
        warn "$pkg_name uses an" "unrecognised endpoint" ". You must
      $spacer specify a file url and version for $action."
        exit 1
    fi

    task "${action}" "$pkg_name"

    $call_action_func
}

_create() {

    echo 'create' $@

}

_install() {

    # INSTALL: Only allow installed version if installed
    if [ "$action" = "install" ] && [ "$installed" ];then
        version="$(get_version $pkg_name -i)"
        if [ ! "$force" ];then
            warn "Already installed" "$pkg_name $version\n" \
         "$spacer Use 'dsm version' to current and latest versions
          $spacer or 'dsm upgrade' to change the installed version"
            exit 1
        fi
    fi

    # UPGRADE AND NEW INSTALL: Use requested or latest version
    if [ "$action" = "upgrade" ] || ! [ "$installed" ]; then
        versiona=($( get_version $pkg_name $version $x_version ))
        version=${versiona[0]}
        x_version=${versiona[1]}
    fi


    debug "version = $version"
    debug "x_version = $x_version"

    # Check if requested version is the same as installed version
    if ! [ "$force" ] || [ "$action" = "upgrade" ]; then
        if [ "$x_version" = "$version" ];then
            ok "Already installed latest version" "$pkg_name $version"
            exit 0
        elif [ "$x_version" ];then
            msg "New version requested $x_version -> $version"
        fi
    fi

    # At this point we need a file, even for archives
    file_path="${file_path:-${version}.tar.gz}"
    file_name="${file_path##*/}"

    required_vars "pkg_name" "file_url" "user" "repo" "version"

    # Convert domain to url
    if [ "$endpoint" ];then
        if is_archive ; then
            file_url="$($endpoint_module get_archive_url $user/$repo $version $file_path)"
        else
            file_url="$($endpoint_module get_file_url $user/$repo $version $file_path)"
        fi
    fi

    pkg_state="${endpoint:-$file_url} -xv $version -xf $file_path -xd $dest_state -xi '${ignore[@]}' $link_state"

    local tmp_dir="$DSM_DIR/temp"

    # Download the package to temp_dir
    stask "Download" "$file_url"
    mkdir -p "$tmp_dir"
    curl -#Lkf "$file_url" -o "$tmp_dir/$file_name"

    pass_or_error $? "download" "check the url and fields below\n" \
                   "$spacer url    : $file_url
                    $spacer repo   : $user/$repo
                    $spacer version: $version
                    $spacer file   : $file_path"

    mkdir -p "$(dirname "$dest")"

    debug "file name : $file_name"
    debug "file path : $file_path"
    debug "dest       : $dest"
    debug "link       : $link"

    # remove existing destination
    if [ -d $dest ] || [ -f $dest ]; then
      debug "remove dest $dest"
      rm -fr $dest
    fi

    # remove existing link location
    if [ -L "$link" ] || [ -f $link ] || [ -d $link ]; then
      debug "remove link $link"
      rm -fr $link
    fi

    # Move files to destination
    if is_archive "$file_path"; then
        extract_archive "$tmp_dir/$file_name" "$dest"
    else
        dsudo chmod -R 755 "$tmp_dir"
        mv -fv "$tmp_dir/$file_name" "$dest" 2>&1 | indent_lines --prefix "Moved  x: "
    fi

    # remove temp_dir (silent)
    rm -fr "$tmp_dir"

    # link final dsm file (dst) to target location (link)
    if [ "$link" ] && ! [ -L "$link" ];then
        ln -sf "$dest" "$link"
        [ $? -eq 0 ] && msg "Linked : $dest -> $link"
    fi

    success_or_exit $? "install" "$pkg_name"

    debug "saving pkg_state = $pkg_state"

    set_state_value "dsman" "${pkg_name}" "$pkg_state"
}

_uninstall () {
    import state state_uninstall
    if [ "$link" ];then
        rm -fr "$link"
        [ $? -eq 0 ] && msg "Removed link from $link"
    fi

    rm -fr "$dest"
    [ $? -eq 0 ] && msg "Removed file from $dest"

    state_uninstall "$STATE_NAME" "$pkg_name"
    success_or_exit $? "uninstall" "$pkg_name from $dest"
}

_upgrade () {
    _install
}

_list () {
    import state freeze_state
    freeze_state "$STATE_NAME"
}

_version () {
    local version=( $(get_version -q "$@" ) )
    local l="${version[0]}"
    local i="${version[1]}"
    if [ "$l" ];then
        if [ "$i" = "$l" ];then
            echo "$i latest version installed"
        else
            echo "installed $i -> requested $l"
        fi
    else
        echo "$i"
    fi
}

is_archive() {
    local file="${1:-$file_path}"
    local return="$2"

    [ "$archive_type" ] && return 0

    if [[ "$file" =~ .*\.zip ]]; then
        archive_type=".zip"
    elif [[ "$file" =~ .*\.tar\.gz ]]; then
        archive_type=".tar.gz"
    elif [ ! "$file" ];then
        archive_type=".tar.gz"
    fi

    [ "$return" ] && echo "$archive_type"

    [ "$archive_type" ]
}

extract_archive () {
    local archive_file="$1"
    local dest="${2:-$PWD}"
    local temp_dir="$(dirname "$archive_file")"

    stask "Extract" "$archive_file"

    case "$archive_file" in
        *tar.gz )    tar -xvf "$archive_file" -C "$tmp_dir" 2>&1 | indent_lines ;;
        *zip )       unzip "$archive_file" -d "$tmp_dir" 2>&1 | indent_lines ;;
    esac

    pass_or_error $? "extract" "archive $archive_file -> $tmp_dir"

    # Remove archive file
    rm -frv "$archive_file" 2>&1 | indent_lines --prefix "Remove: "

    stask "Moving" "files -> $dest"

    # Remove ignored files from tmp_dir
    local x
    for x in "${ignore[@]}";do
        rm -frv "$tmp_dir"/*/$x 2>&1 | indent_lines --prefix "Ignored: "
    done

    chmod -R 755 "$tmp_dir"

    # Move remaining files to dest
    mv -fv "$tmp_dir"/* "$dest" 2>&1 | indent_lines --prefix "Moved  : "
}

get_version() {

    local pkg req_version x_version quiet get_latest get_installed
    local values=()
    local rv=0

    debug "  get_version got: $*"

    local usage="dsm version <pkg_name> [-l, --latest] [-i, --installed] [-q, --quiet]"

    check_for_help $1

    while [[ $# > 0 ]]; do
        case "$1" in
        -q | --quiet)       quiet=true;;
        -l | --latest)      get_latest=true;;
        -i | --installed )  get_installed=true;;
        --debug )           DEBUG=true;;
        *)  uncaught_case "$1" "pkg" "req_version" "x_version";;
        esac
        shift
    done

    debug "    get_version parse : $pkg r:$req_version x:$x_version -q $quiet -l $get_latest -i $get_installed"

    # convert latest to none
    [ "$req_version" = "latest" ] && req_version=""

    if [[ ! "$get_installed" && ! "$get_latest" ]];then
        get_installed=true
        get_latest=true
    fi

    if [ "$get_installed" ];then
        if [ ! "$x_version" ]; then
            local state=( $(get_state_value "$STATE_NAME" "$pkg") )
            if [[ "${state[0]}" =~ .*://.* ]];then
                x_version="${state[2]}"
            else
                x_version="${state[3]}"
            fi
        fi
    fi

    # only check for new version if unspecified
    if [ "$get_latest" ] && [ ! "$req_version" ]; then

        # Get latest version for endpoints
        debug "$file_url"
        if [ "$endpoint" ]; then
            if cmd_exists python;then
                [ ! "$quiet" ] && stask "Check latest version" "$user/$repo"
                req_version="$($endpoint_module get_latest_release "$user/$repo" 2> /dev/null)"
            else
                [ ! "$quiet" ] && warn "python is required to get latest tag"
            fi
        fi
    fi


    if [ ! "$req_version" ];then
        if [ ! "$get_latest" ] ;then
            req_version="${x_version}"

        # use master if latest is requested
        else
            warn "Latest version not found, using master branch" 1>&2
            req_version="master"
            rv=1
        fi
    fi

    debug "-FINAL VERSIONS = req:$req_version installed:$x_version"

    [ "$get_latest" ] && echo "$req_version"
    [ "$get_installed" ] && echo "$x_version"

    return $rv
}

parse_url () {
    local url="${1/:\/}"
    local i length

    IFS='/'
    url_array=( $url )
    protocol="${url_array[0]}"
    domain="${url_array[1]}"
    user="${url_array[2]}"
    repo="${url_array[3]}"
    raw="${url_array[4]}"

    file_name="${url_array[${#url_array[@]} - 1]}"
    archive_type="$(is_archive "$file_name" -r)"

    # get version from archive file or url
    if [ "$archive_type" ];then
        version="${file_name%$archive_type}"
        i=5
    else
        version="${url_array[5]}"
        i=6
    fi

    file_path=()
    length=${#url_array[@]}
    while [ $i -le $length ]; do
        file_path+=("${url_array[i]}")
        unset url_array[i]
        ((i++))
    done

    file_path="${file_path[*]}"
    file_path="${file_path%/}"
    url_array[6]="${file_path}"
    unset IFS

    if ! [ "$file_path" ];then
        error "The url was not parsed correctly, please check
      $spacer the url. You many need to add a version filed.
      $spacer protocol=${url_array[0]}
      $spacer domain=${url_array[1]}
      $spacer user=${url_array[2]}
      $spacer repo=${url_array[3]}
      $spacer raw=${url_array[4]}
      $spacer version=${url_array[5]}
      $indent file=${file_path[*]}"
        exit 1
    fi

    case "$domain" in
    *github.com )    endpoint="github";;
    *bitbucket.com ) endpoint="bitbucket";;
    esac

    if [ "$endpoint" ];then
        endpoint_module="$endpoint"
        endpoint="$endpoint $user/$repo"
        debug "parse_url found endpoint : $endpoint"
    fi

    # clear file for archives
    if is_archive; then
        file_path=""
        file_name=""
    fi
}

task() {
  local t="$1"
  shift
  local text="$(compile_text $cyan $dark_cyan "$@")"
  printf "$(op_prefix "$t" $dark_cyan) %b%b\n" "$text" $rc 1>&2
}

stask() {
  local t="$1"
  shift
  local text="$(compile_text $cyan $dark_cyan "$@")"
  printf "$(sop_prefix "$t" $dark_cyan) %b%b\n" "$text" $rc 1>&2
}

warn() {
  local text="$(compile_text $yellow $dark_yellow "$@")"
  printf "$(sop_prefix "WARNING" $dark_yellow) %b%b\n" "$text" $rc 1>&2
}

ok() {
  local text="$(compile_text $green $dark_green "$@")"
  printf  "$(sop_prefix "OK" $dark_green) %b%b\n" "$text" $rc 1>&2
}

msg() {
    printf "$indent $1\n" 1>&2
}

success_or_exit () {
    local state=$1
    local action="$2"
    shift; shift
    if [ $state -eq 0 ];then
        local text="$(compile_text $green $dark_green "$@")"
        printf  "$(sop_prefix "${action%e}ed" $dark_green) %b%b\n" "$text" $rc 1>&2
    else
        local text="$(compile_text $red $dark_red "Could not $action" "$@")"
        printf  "$(sop_prefix "Error" $dark_red) %b%b\n" "$text" $rc 1>&2
        exit 1
    fi
    return $state
}

pass_or_error () {
    local state=$1
    local action="$2"
    shift; shift
    if ! [ $state -eq 0 ];then
        local text="$(compile_text $red $dark_red "Could not $action" "$@")"
        printf  "$(sop_prefix "ERROR" $dark_red) %b%b\n" "$text" $rc 1>&2
        exit 1
    fi
    return $state
}

op_prefix() {
    action="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
    printf  "\r%b%bDSM-$action}%b" $clear_line $2 $rc
}

sop_prefix() {
    action="$1"
    printf  "\r%b%b$action}%b" $clear_line $2 $rc
}

export op_prefix

authenticate(){
    local auth="${1:-$auth}"
    [ ! "$auth" ] && return

    local auth_u="${auth%:*}"
    local auth_p="${auth#*:}"

    if [ "$auth_u" = "$auth_p" ];then
        auth_p=""
    esle
        auth_p=":$auth_p"
    fi

    if [ "$auth_u" = '*' ];then
        auth_u= "$(git config user.name)"
    fi

    echo "-u $auth_u$auth_p"
}

manage_topic_dsm() {

    local usage="manage_topic_dsm [<option>]"
    local usage_full="
    --force        Force action for dsm
    "

    local action="$1"
    local topic="$2"
    shift; shift

    local force

    while [[ $# > 0 ]]; do
        case "$1" in
        --force )      force="--force" ;;
        -l | --link )  link="--link" ;;
        *)  invalid_option "$1" || exit 1;;
        esac
        shift
    done

    local u_dir="$(topic_dir "$topic" "user")"
    local b_dir="$(topic_dir "$topic" "builtin")"

    local b_files u_files

    debug "-- manage_topic_dsm: $@ $force"


    if [ -d "$b_dir" ]; then
        b_files=( $(find "$b_dir" -mindepth 1 $type -name "*.dsm" -not -name '\.*') )
    fi
    if [ -d "$u_dir" ] && [ "$topic" != "dotsys" ]; then
        u_files=( $(find "$u_dir" -mindepth 1 $type -name "*.dsm" -not -name '\.*') )
    fi

    debug "   manage_topic_dsm u_files: ${u_files[@]}"

    if ! [ "$u_files" ] && ! [ "$b_files" ]; then
        debug "   manage_topic_dsm: ABORT no files found for $topic"
        return
    fi

    debug "  manage_topic_dsm: a:$action t:$topic f:$force l:$link"
    debug "   manage_topic_dsm b_dir : $b_dir"
    debug "   manage_topic_dsm u_dir : $u_dir"
    local rv=0
    local files file dsm_cmd file_name file_cmd
    local all_files="b_files[@] u_files[@]"
    local owd="$PWD"

    for files in $all_files;do
        debug "files = $files"
        for file in "${!files}"; do
            debug "   file: $file"
            ! [ "$file" ] && continue

            # chane to file directory
            cd "$(dirname "$file")"

            # use file name as dsm pkg name
            file_name="$(basename "${file%.dsm}")"
            file_cmd=$(head -n 1 "$file")
            dsm_cmd="$file_name $file_cmd $force $link"

            if [ "$action" = "freeze" ]; then
                freeze_msg "dsm" "$dsm_cmd"
                return
            fi

            debug "   dsm: $dsm_cmd"
            dsman "$action" $dsm_cmd
            [ ! $? -eq 0 ] && rv=1
        done
    done
    cd "$owd"

    [ ! $rv -eq 0 ] && echo "There was an issue with a .dsm file for $topic"
    return $rv
}

if [[ "$(basename $0)" =~ ^dsm$|^dsman$ ]]; then
dsman "$@"
fi
