install () {
    upgrade
}

upgrade () {
    sudo npm install npm -g
}

update () {
    upgrade
}

freeze () {
    npm ls
}

$@