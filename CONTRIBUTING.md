
# Contributing

You're thinking of contributing something to one of my projects? Oh my, I'm
quite honoured! Here's what you need to know.


## Writing

Clone the repository from either [BitBucket][] (if you're into Mercurial) or
[GitHub][] (if you're into Git).

Next, create a branch for your work -- don't work directly on the `defaut` or
`master` branch. Instead, in Mercurial:

  $ hg bookmark my-fix

Or, in Git:

  $ git checkout -b my-fix master

Make your changes. Don't write anything that's not related to the fix you're
trying to contribute to the project.

Write a simple, concise commit message. Gutentags isn't a big piece of code so
no need for strict message formats, so don't get fancy.


## Testing

If you can, try and test your changes on multiple platforms -- Ubuntu, MacOS,
and Windows are supposed to be supported.

Also try to test your changes with:

1. `g:gutentags_cache_dir` enabled and disabled.
2. A repository with spaces in its root path.
3. A repository with files and folders that have spaces in them.

If you're on NeoVim, try and test on a "normal" Vim.


## Pushing

Once everything's fine, go on BitBucket or GitHub (again, depending on your
favorite source control tool) and create a fork if you haven't done so yet. Push
your changes to your fork, and create a pull request. Check the documentation of
either code portal for more information.

Don't worry if you don't see any reply from me for a while. My turn around time
is measured in weeks, sometimes in months. This is normal -- I've got a job,
a family, and open-source hacking is only one of many awesome hobbies I spend my
limited free time on.

That's it for now! And thanks a lot for contributing!


[bitbucket]: https://bitbucket.org/ludovicchabant/vim-gutentags
[github]: https://github.com/ludovicchabant/vim-gutentags

