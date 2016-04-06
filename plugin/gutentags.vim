" gutentags.vim - Automatic ctags management for Vim
" Maintainer:   Ludovic Chabant <http://ludovic.chabant.com>
" Version:      0.0.1

" Globals {{{

if v:version < 704
    echoerr "gutentags: this plugin requires vim >= 7.4."
    finish
endif

if !exists('g:gutentags_debug')
    let g:gutentags_debug = 0
endif

if (exists('g:loaded_gutentags') || &cp) && !g:gutentags_debug
    finish
endif
if (exists('g:loaded_gutentags') && g:gutentags_debug)
    echom "Reloaded gutentags."
endif
let g:loaded_gutentags = 1

if !exists('g:gutentags_trace')
    let g:gutentags_trace = 0
endif

if !exists('g:gutentags_fake')
    let g:gutentags_fake = 0
endif

if !exists('g:gutentags_background_update')
    let g:gutentags_background_update = 1
endif

if !exists('g:gutentags_pause_after_update')
    let g:gutentags_pause_after_update = 0
endif

if !exists('g:gutentags_enabled')
    let g:gutentags_enabled = 1
endif

if !exists('g:gutentags_enabled_user_func')
    let g:gutentags_enabled_user_func = ''
endif

if !exists('g:gutentags_modules')
    let g:gutentags_modules = ['ctags']
endif

if !exists('g:gutentags_project_root')
    let g:gutentags_project_root = ['.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
endif

if !exists('g:gutentags_project_info')
    let g:gutentags_project_info = []
endif
call add(g:gutentags_project_info, {'type': 'python', 'file': 'setup.py'})
call add(g:gutentags_project_info, {'type': 'ruby', 'file': 'Gemfile'})

if !exists('g:gutentags_exclude')
    let g:gutentags_exclude = []
endif

if !exists('g:gutentags_resolve_symlinks')
    let g:gutentags_resolve_symlinks = 0
endif

if !exists('g:gutentags_generate_on_new')
    let g:gutentags_generate_on_new = 1
endif

if !exists('g:gutentags_generate_on_missing')
    let g:gutentags_generate_on_missing = 1
endif

if !exists('g:gutentags_generate_on_write')
    let g:gutentags_generate_on_write = 1
endif

if !exists('g:gutentags_cache_dir')
    let g:gutentags_cache_dir = ''
else
    " Make sure we get an absolute/resolved path (e.g. expanding `~/`), and
    " strip any trailing slash.
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':p')
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':s?[/\\]$??')
endif

if !exists('g:gutentags_define_advanced_commands')
    let g:gutentags_define_advanced_commands = 0
endif

if g:gutentags_cache_dir != '' && !isdirectory(g:gutentags_cache_dir)
    call mkdir(g:gutentags_cache_dir, 'p')
endif

if has('win32')
    let g:gutentags_plat_dir = expand('<sfile>:h:h:p') . "\\plat\\win32\\"
    let g:gutentags_res_dir = expand('<sfile>:h:h:p') . "\\res\\"
    let g:gutentags_script_ext = '.cmd'
else
    let g:gutentags_plat_dir = expand('<sfile>:h:h:p') . '/plat/unix/'
    let g:gutentags_res_dir = expand('<sfile>:h:h:p') . '/res/'
    let g:gutentags_script_ext = '.sh'
endif

" }}}

" Gutentags Setup {{{

augroup gutentags_detect
    autocmd!
    autocmd BufNewFile,BufReadPost *  call gutentags#setup_gutentags()
    autocmd VimEnter               *  if expand('<amatch>')==''|call gutentags#setup_gutentags()|endif
augroup end

" }}}

" Toggles and Miscellaneous Commands {{{

command! GutentagsUnlock :call gutentags#delete_lock_files()

if g:gutentags_define_advanced_commands
    command! GutentagsToggleEnabled :let g:gutentags_enabled=!g:gutentags_enabled
    command! GutentagsToggleTrace   :call gutentags#toggletrace()
endif

if g:gutentags_debug
    command! GutentagsToggleFake    :call gutentags#fake()
endif

" }}}

