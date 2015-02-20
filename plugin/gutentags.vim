" gutentags.vim - Automatic ctags management for Vim
" Maintainer:   Ludovic Chabant <http://ludovic.chabant.com>
" Version:      0.0.1

" Globals {{{

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

if !exists('g:gutentags_modules')
    let g:gutentags_modules = ['ctags']
endif

if !exists('g:gutentags_project_root')
    let g:gutentags_project_root = []
endif
let g:gutentags_project_root += ['.git', '.hg', '.svn', '.bzr', '_darcs']

if !exists('g:gutentags_exclude')
    let g:gutentags_exclude = []
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
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':s?[/\\]$??')
endif

if g:gutentags_cache_dir != '' && !isdirectory(g:gutentags_cache_dir)
    call mkdir(g:gutentags_cache_dir, 'p')
endif

if has('win32')
    let g:gutentags_plat_dir = expand('<sfile>:h:h:p') . "\\plat\\win32\\"
    let g:gutentags_script_ext = '.cmd'
else
    let g:gutentags_plat_dir = expand('<sfile>:h:h:p') . '/plat/unix/'
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

function! s:delete_lock_files() abort
    for tagfile in values(b:gutentags_files)
        silent call delete(tagfile.'.lock')
    endfor
endfunction

command! GutentagsToggleEnabled :let g:gutentags_enabled=!g:gutentags_enabled
command! GutentagsToggleTrace   :call gutentags#trace()
command! GutentagsUnlock        :call s:delete_lock_files()

if g:gutentags_debug
    command! GutentagsToggleFake    :call gutentags#fake()
endif

" }}}

