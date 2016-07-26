#!/bin/bash

# Returns a list directory names in a directory
get_dir_list () {
    local dir="$1"
    local force="$2"
    local list
    local t

    if ! [ -d "$dir" ];then return 1;fi
    list="$(find "$dir" -mindepth 1 -maxdepth 1 -type d -not -name '\.*')"

    for t in ${list[@]}; do
        echo "$(basename "$t") "
    done
}

# return a list of unique values
unique_list () {
    local var="$1"
    local seen
    local word

    for word in $var; do
      case $seen in
        $word\ * | *\ $word | *\ $word\ * | $word)
          # already seen
          ;;
        *)
          seen="$seen $word"
          ;;
      esac
    done
    echo $seen
}

replace_file_string () {
    local file="$1"
    local rm_str="$2"
    local rp_str="$3"
    sedi "s|$rm_str|$rp_str|g" "$file"
}

remove_file_line () {
    local file="$1"
    local rm_str="$2"
    sedi "\|$rm_str|d" "$file"
}

sedi () {
    # BSD sed does not have a --version option and GNU sed does
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}


rename_all() {
    import input get_user_input

    local files="$(find "$1" -type f -name "$2")"
    local file
    local new
    while IFS=$'\n' read -r file; do
        new="$(dirname "$file")/$3"
        get_user_input "rename $file -> $new"
        if [ $? -eq 0 ]; then
            mv "$file" "$new"
        fi

    done <<< "$files"
}

# ARRAY UTILS

# not used
is_array() {
  local var=$1
  [[ "$(declare -p $var)" =~ "declare -a" ]]
}

#Reverse order of array
#USAGE: reverse_array arrayname
reverse_array() {
    local arrayname=${1:?Array name required}
    local array
    local revarray
    local e

    #Copy the array, $arrayname, to local array
    eval "array=( \"\${$arrayname[@]}\" )"

    #Copy elements to revarray in reverse order
    for e in "${array[@]}"; do
    revarray=( "$e" "${revarray[@]}" )
    done

    #Copy revarray back to $arrayname
    eval "$arrayname=( \"\${revarray[@]}\" )"
}


#Test if value is in an array
#USAGE: array_contains arrayname
array_contains () {
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

escape_sed() {
 sed \
  -e 's/\&/\\\&/g'
}

# Convert windows line endings to unix as required
fix_crlf () {

    if ! cmd_exists dos2unix; then reutrn; fi

    local files

    if [ "$1" = "system" ]; then
        files="$(find "$DOTSYS_REPOSITORY" -type f -not -path "$DOTSYS_REPOSITORY/\.*")"
    elif [ "$1" ]; then
        files="$(find "$1" -type f -not -path "$1/\.*")"
    else
        files="$(find . -type f -not -path ".*/\.*")"
    fi

    local file
    while IFS=$'\n' read -r file; do
        dos2unix "$file"
    done <<< "$files"
}