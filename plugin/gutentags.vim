" gutentags.vim - Automatic ctags management for Vim
" Maintainer:   Ludovic Chabant <http://ludovic.chabant.com>
" Version:      2.0.0

" Globals {{{

if (&cp || get(g:, 'gutentags_dont_load', 0))
    finish
endif

if v:version < 704
    echoerr "gutentags: this plugin requires vim >= 7.4."
    finish
endif

if !(has('job') || (has('nvim') && exists('*jobwait')))
    echoerr "gutentags: this plugin requires the job API from Vim8 or Neovim."
    finish
endif

let g:gutentags_debug = get(g:, 'gutentags_debug', 0)

if (exists('g:loaded_gutentags') && !g:gutentags_debug)
    finish
endif
if (exists('g:loaded_gutentags') && g:gutentags_debug)
    echom "Reloaded gutentags."
endif
let g:loaded_gutentags = 1

let g:gutentags_trace = get(g:, 'gutentags_trace', 0)
let g:gutentags_fake = get(g:, 'gutentags_fake', 0)
let g:gutentags_background_update = get(g:, 'gutentags_background_update', 1)
let g:gutentags_pause_after_update = get(g:, 'gutentags_pause_after_update', 0)
let g:gutentags_enabled = get(g:, 'gutentags_enabled', 1)
let g:gutentags_modules = get(g:, 'gutentags_modules', ['ctags'])

let g:gutentags_init_user_func = get(g:, 'gutentags_init_user_func', 
            \get(g:, 'gutentags_enabled_user_func', ''))

let g:gutentags_add_default_project_roots = get(g:, 'gutentags_add_default_project_roots', 1)
let g:gutentags_project_root = get(g:, 'gutentags_project_root', [])
if g:gutentags_add_default_project_roots
    let g:gutentags_project_root += ['.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
endif

let g:gutentags_project_root_finder = get(g:, 'gutentags_project_root_finder', '')

let g:gutentags_project_info = get(g:, 'gutentags_project_info', [])
call add(g:gutentags_project_info, {'type': 'python', 'file': 'setup.py'})
call add(g:gutentags_project_info, {'type': 'ruby', 'file': 'Gemfile'})

let g:gutentags_exclude_project_root = get(g:, 'gutentags_exclude_project_root', ['/usr/local'])
let g:gutentags_resolve_symlinks = get(g:, 'gutentags_resolve_symlinks', 0)
let g:gutentags_generate_on_new = get(g:, 'gutentags_generate_on_new', 1)
let g:gutentags_generate_on_missing = get(g:, 'gutentags_generate_on_missing', 1)
let g:gutentags_generate_on_write = get(g:, 'gutentags_generate_on_write', 1)
let g:gutentags_generate_on_empty_buffer = get(g:, 'gutentags_generate_on_empty_buffer', 0)
let g:gutentags_file_list_command = get(g:, 'gutentags_file_list_command', '')

let g:gutentags_use_jobs = get(g:, 'gutentags_use_jobs', has('job'))

if !exists('g:gutentags_cache_dir')
    let g:gutentags_cache_dir = ''
elseif !empty(g:gutentags_cache_dir)
    " Make sure we get an absolute/resolved path (e.g. expanding `~/`), and
    " strip any trailing slash.
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':p')
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':s?[/\\]$??')
endif

let g:gutentags_define_advanced_commands = get(g:, 'gutentags_define_advanced_commands', 0)

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

if g:gutentags_define_advanced_commands
    command! GutentagsToggleEnabled :let g:gutentags_enabled=!g:gutentags_enabled
    command! GutentagsToggleTrace   :call gutentags#toggletrace()
endif

if g:gutentags_debug
    command! GutentagsToggleFake    :call gutentags#fake()
endif

" }}}

