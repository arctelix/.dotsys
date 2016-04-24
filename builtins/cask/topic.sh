#!/bin/sh

install () {
  brew tap caskroom/cask
}

uninstall () {
  brew untap caskroom/cask
}

upgrade () {
  brew cask upgrade
}

update () {
  brew cask update
}

freeze () {
  brew cask list
}

$@ # Required for function execution



# removed apps
#    bash-completion2
#    bats
#    battery
#    coreutils
#    cmake
#    dockutil
#    ffmpeg
#    fasd
#    gifsicle
#    git
#    gnu-sed --with-default-names
#    grep --with-default-names
#    hub
#    httpie
#    imagemagick
#    jq
#    mackup
#    peco
#    psgrep
#    python
#    shellcheck
#    ssh-copy-id
#    svn
#    tree
#    vim
#    wget
#    wifi-password
