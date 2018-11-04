---
name: Bug report
about: Something's wrong?

---

**Describe the bug**
Describe what the bug is about, and what you expected. Don't forget to format things nicely with Markdown. If applicable, post screenshots.

**Steps to reproduce**
1. Do this '...'
2. Do that '...'
3. Etc.

**Share your setup**
- What OS and version of Vim are you using?
- What version of `ctags`, `gtags`, or whatever do you have installed?
- Are you using `g:gutentags_cache_dir`?

**Post the logs**
- Run `:let g:gutentags_trace = 1`.
- Reproduce the bug.
- Run `:messages` and show the messages that Gutentags posted.
- Look for the `tags.log` file that Gutentags' script left behind, and post its contents.

**Additional context**
Add any other context about the problem here.
