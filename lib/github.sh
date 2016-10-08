#!/usr/bin/env bash

create_repo () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    curl -u "$user" https://api.github.com/user/repos -d "{\"name\":\"${repo}\"}"
}

get_archive () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    curl -L https://github.com/$user/$repo/archive/$version.tar.gz | tar xv
}

get_archive_file () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    local file="${2#*/}"
    local version="${3:-master}"
    curl -L https://github.com/$user/$repo/raw/$version/$file | tar xv
}

get_latest_release () {
    local user="${1%/*}"
    local repo="${1#*/}"
    shift; shift
    curl -#f $(authenticate "$@") https://api.github.com/repos/$user/$repo/releases/latest | \
        python -c "import sys, json; print json.load(sys.stdin).get('tag_name','')"
}

get_file_url () {
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    local file="${3}"

    echo "https://raw.githubusercontent.com/$user/$repo/$version/$file"
}

get_archive_url () {
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    local file="${3}"
    echo "https://github.com/$user/$repo/archive/$file"
}