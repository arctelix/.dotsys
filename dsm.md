What's the DSM thing you were raving about?
-------------------------------------------
I's super simple. Use any url to a file or archive (.zip, .tar.gz) and dsm will download it and extract
it to the present working directory or a --destination (-d) of your choice.  For github and bit bucket
you can use a shortcut syntax.

    # install files
    dsm install http://domain.com/path/to/file
    dsm install github user/repo -f file
    dsm install gh user/repo -f file

    # install archives
    dsm install http://domain.com/path/to/archive.tar.gz
    dsm install github user/repo
    dsm install gh user/repo


That's great, but what does that have to do with dotsys?
-------------------------------------------------------
It's especially great for when you just need to add a couple of files from a repo to a topic.  Just add a .dsm
file and include a dsm install command on the first line.  For example:

    gh user/repo -f some_repo_file.sh

Now wen you run `dotsys install mytopic` some_repo_file.sh will be downloaded and symlinked to the location
of the .dsm file.  Need to make that file a .symlink, no problem:

    gh user/repo -f some_repo_file.sh -d renamed.symlink

Dsm can also be used as a dotsys manager.  Just add the following keys to your topic.sh file to have dsm manage
the topic.  The dsm key value must be a valid dsm install command.

    manager: dsm
    dsm: github user/repo

Dsm will extract the contents of your repo to topic/repo.  Now create symlinks to any file from the repo you
want to integrate with your dotsys topic.  For example cd into your topic directory and do things like this:

    ln -s repo/.dotfile dotfile.symlink
    ln -s repo/mycmd.sh bin/renamedcmd

Again, the repo contents are symlinked to your topic, so the actual files are not part of your repo!

Is that all?
------------

There allot more power here.  For example, dsm will ignore commonly unwanted files when extracting archives like
.gitignore, bats, *.md, docs, tests.  You can add to that list with `-i 'file *.ext'` or replace it with `-ir ''`.

Use 'dsm --help' for all options and usage.