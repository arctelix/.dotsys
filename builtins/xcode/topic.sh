#!/bin/bash

# xcode

install () {
   xcode-select --install 2>/dev/null

   # xcode returns 1 if installed
   [ $? -eq 1 ] && return 0

   #get_user_input "Choose install in the xcode dialogue box and confirm
   #        $spacer and confirm AFTER install is completed" -t installed -f ""

   info "Xcode is required, choose 'install' in the xcode dialogue box to continue
 $spacer waiting for xcode installation to complete use control-c to exit"

   local dots=""
   while ! xcode-select -p >/dev/null 2>&1; do
       dots=".$dots"
       printf "$spacer $dots"
       sleep 5
   done

   return 0
}

uninstall () {
  [ -d "$(xcode-select -p)" ] && dsudo rm -fr "$(xcode-select -p)"
  return $?
}


freeze () {
  xcode-select -v
  return $?
}

"$@"

