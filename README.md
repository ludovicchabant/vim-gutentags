
# Gutentags

Gutentags is a plugin that takes care of the much needed management of tags
files in Vim. It will (re)generate tag files as you work while staying
completely out of your way. It will even do its best to keep those tag files
out of your way too. It has no dependencies and just works.


## How?

Install Gutentags like any other Vim plugin. I recommend something like
[Pathogen][], so you can go:

    cd ~/.vim/bundle
    hg clone https://bitbucket.org/ludovicchabant/vim-gutentags

If you're more into Git than Mercurial:

    git clone https://github.com/ludovicchabant/vim-gutentags.git

Then you only need to do a `:call pathogen#helptags()` to generate the
documentation tags (how ironic, eh?) and you can access Gutentags' help pages
with `help gutentags`.


## What?

In order to generate tag files, Gutentags will have to figure out what's in
your project. To do this, it will locate well-known project root markers like
SCM folders (`.git`, `.hg`, etc.), any custom tags you define (with
`gutentags_project_root`), and even things you may have defined already with
other plugins, like [CtrlP][].

If the current file you're editing is found to be in such a project, Gutentags
will make sure the tag file for that project is up to date. Then, as you work
in files in that project, it will partially re-generate the tag file. Every
time you save, it will silently, in the background, update the tags for that
file.

Usually, ctags can only append tags to an existing tag file, so Gutentags
removes the tags for the current file first, to make sure the tag file is
always consistent with the source code.

Also, Gutentags is clever enough to not stumble upon itself by triggering
multiple ctags processes if you save files too fast, or your project is really
big.


## Why?

There are some similar Vim plugins out there ("vim-tags", "vim-autotag",
"vim-automatic-ctags", etc.). They all fail on one or more of the requirements
I set for myself with Gutentags:

* No other dependency than running Vim: no Python, Ruby, or whatever.
* Cross-platform: should work on at least Ubuntu, Mac, and Windows.
* Incremental tags generation: don't re-generate the whole project all the time.
  This may be fine for small projects, but it doesn't scale.
* External process management: if the ctags process is taking a long time, don't
  run another one because I saved a file again.
* Keep the tag file consistent: don't just append the current file's tags to the
  tag file, otherwise you will still "see" tags for deleted or renamed classes
  and functions.
* Automatically create the tag file: you open something from a freshly forked
  project, it should start indexing it automatically, just like in Sublime Text
  or Visual Studio or any other IDE.

I hope Gutentags will bring you as much closure as me regarding tag files. I know
I don't want to have to think about it, and probably neither do you.


[Pathogen]: https://github.com/tpope/vim-pathogen
[ctrlp]: https://github.com/kien/ctrlp.vim

