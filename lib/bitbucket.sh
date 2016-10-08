#!/usr/bin/env bash

import dsm authenticate

create_repo () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    curl -f -u "$repo_user" https://api.github.com/user/repos -d "{\"name\":\"${repo}\"}"
}

get_archive () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    curl -Lf https://github.com/$repo_user/$repo_name/archive/$version.tar.gz | tar xv
}

get_archive_file () {
    # parse user/repo
    local user="${1%/*}"
    local repo="${1#*/}"
    local file="${2#*/}"
    local version="${3:-master}"
    curl -Lf https://github.com/$repo_user/$repo_name/raw/$version/$file | tar xv
}

get_latest_release () {
    local user="${1%/*}"
    local repo="${1#*/}"
    shift; shift
    curl -#f $(authenticate "$@") https://api.bitbucket.org/2.0/repositories/$user/$repo/refs/tags | \
        python -c "import sys, json; \
                   values=json.load(sys.stdin)['values']; \
                   print max( [x['name'] for x in values if not x['name'].isalpha()]);"
}

get_file_url () {
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    local file="${3}"
    echo "https://bitbucket.org/$user/$repo/raw/$version/$file"
}

get_archive_url () {
    local user="${1%/*}"
    local repo="${1#*/}"
    local version="${2:-master}"
    local file="${3}"
    echo "https://bitbucket.org/$user/$repo/get/$file"
}