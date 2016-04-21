#!/bin/sh
# Install Homebrew

# These functions are executed

install () {
  xcode-select --install
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

uninstall () {
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)"
}

upgrade () {
  brew upgrade
}

reload () {
  brew update
}

freeze () {
  brew list
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
