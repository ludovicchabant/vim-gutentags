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

if !exists('g:gutentags_executable')
    let g:gutentags_executable = 'ctags'
endif

if !exists('g:gutentags_tagfile')
    let g:gutentags_tagfile = 'tags'
endif

if !exists('g:gutentags_project_root')
    let g:gutentags_project_root = []
endif
let g:gutentags_project_root += ['.git', '.hg', '.svn', '.bzr', '_darcs']

if !exists('g:gutentags_options_file')
    let g:gutentags_options_file = ''
endif

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

if !exists('g:gutentags_auto_set_tags')
    let g:gutentags_auto_set_tags = 1
endif

if !exists('g:gutentags_cache_dir')
    let g:gutentags_cache_dir = ''
else
    let g:gutentags_cache_dir = fnamemodify(g:gutentags_cache_dir, ':s?[/\\]$??')
endif

if g:gutentags_cache_dir != '' && !isdirectory(g:gutentags_cache_dir)
    call mkdir(g:gutentags_cache_dir, 'p')
endif

" }}}

" Utilities {{{

" Throw an exception message.
function! s:throw(message)
    let v:errmsg = "gutentags: " . a:message
    throw v:errmsg
endfunction

" Prints a message if debug tracing is enabled.
function! s:trace(message, ...)
   if g:gutentags_trace || (a:0 && a:1)
       let l:message = "gutentags: " . a:message
       echom l:message
   endif
endfunction

" Strips the ending slash in a path.
function! s:stripslash(path)
    return fnamemodify(a:path, ':s?[/\\]$??')
endfunction

" Normalizes the slashes in a path.
function! s:normalizepath(path)
    if exists('+shellslash') && &shellslash
        return substitute(a:path, '\v/', '\\', 'g')
    elseif has('win32')
        return substitute(a:path, '\v/', '\\', 'g')
    else
        return a:path
    endif
endfunction

" Shell-slashes the path (opposite of `normalizepath`).
function! s:shellslash(path)
  if exists('+shellslash') && !&shellslash
    return substitute(a:path, '\v\\', '/', 'g')
  else
    return a:path
  endif
endfunction

" }}}

" Gutentags Setup {{{

let s:known_tagfiles = []

" Finds the first directory with a project marker by walking up from the given
" file path.
function! s:get_project_root(path) abort
    let l:path = s:stripslash(a:path)
    let l:previous_path = ""
    let l:markers = g:gutentags_project_root[:]
    if exists('g:ctrlp_root_markers')
        let l:markers += g:ctrlp_root_markers
    endif
    while l:path != l:previous_path
        for root in g:gutentags_project_root
            if getftype(l:path . '/' . root) != ""
                let l:proj_dir = simplify(fnamemodify(l:path, ':p'))
                return s:stripslash(l:proj_dir)
            endif
        endfor
        let l:previous_path = l:path
        let l:path = fnamemodify(l:path, ':h')
    endwhile
    call s:throw("Can't figure out what tag file to use for: " . a:path)
endfunction

" Get the tag filename for a given project root.
function! s:get_tagfile(root_dir) abort
    let l:tag_path = s:stripslash(a:root_dir) . '/' . g:gutentags_tagfile
    if g:gutentags_cache_dir != ""
        " Put the tag file in the cache dir instead of inside the
        " projet root.
        let l:tag_path = g:gutentags_cache_dir . '/' .
                    \tr(l:tag_path, '\/:', '---')
        let l:tag_path = substitute(l:tag_path, '/\-', '/', '')
    endif
    let l:tag_path = s:normalizepath(l:tag_path)
    return l:tag_path
endfunction

" Setup gutentags for the current buffer.
function! s:setup_gutentags() abort
    if exists('b:gutentags_file') && !g:gutentags_debug
        " This buffer already has gutentags support.
        return
    endif

    " Try and find what tags file we should manage.
    call s:trace("Scanning buffer '" . bufname('%') . "' for gutentags setup...")
    try
        let b:gutentags_root = s:get_project_root(expand('%:h'))
        let b:gutentags_file = s:get_tagfile(b:gutentags_root)
    catch /^gutentags\:/
        call s:trace("Can't figure out what tag file to use... no gutentags support.")
        return
    endtry

    " We know what tags file to manage! Now set things up.
    call s:trace("Setting gutentags for buffer '" . bufname('%') . "' with tagfile: " . b:gutentags_file)

    " Set the tags file for Vim to use.
    if g:gutentags_auto_set_tags
        execute 'setlocal tags^=' . fnameescape(b:gutentags_file)
    endif

    " Autocommands for updating the tags on save.
    let l:bn = bufnr('%')
    execute 'augroup gutentags_buffer_' . l:bn
    execute '  autocmd!'
    execute '  autocmd BufWritePost <buffer=' . l:bn . '> call s:write_triggered_update_tags()'
    execute 'augroup end'

    " Miscellaneous commands.
    command! -buffer -bang GutentagsUpdate :call s:manual_update_tags(<bang>0)

    " Add this tags file to the known tags files if it wasn't there already.
    let l:found = index(s:known_tagfiles, b:gutentags_file)
    if l:found < 0
        call add(s:known_tagfiles, b:gutentags_file)

        " Generate this new file depending on settings and stuff.
        if g:gutentags_generate_on_missing && !filereadable(b:gutentags_file)
            call s:trace("Generating missing tags file: " . b:gutentags_file)
            call s:update_tags(1, 0)
        elseif g:gutentags_generate_on_new
            call s:trace("Generating tags file: " . b:gutentags_file)
            call s:update_tags(1, 0)
        endif
    endif
endfunction

augroup gutentags_detect
    autocmd!
    autocmd BufNewFile,BufReadPost *  call s:setup_gutentags()
    autocmd VimEnter               *  if expand('<amatch>')==''|call s:setup_gutentags()|endif
augroup end

" }}}

"  Tags File Management {{{

let s:runner_exe = expand('<sfile>:h:h') . '/plat/unix/update_tags.sh'
if has('win32')
    let s:runner_exe = expand('<sfile>:h:h') . '\plat\win32\update_tags.cmd'
endif

let s:update_queue = []
let s:maybe_in_progress = {}

" Get how to execute an external command depending on debug settings.
function! s:get_execute_cmd() abort
    if has('win32')
        let l:cmd = '!start '
        if g:gutentags_background_update
            let l:cmd .= '/b '
        endif
        return l:cmd
    else
        return '!'
    endif
endfunction

" Get the suffix for how to execute an external command.
function! s:get_execute_cmd_suffix() abort
    if has('win32')
        return ''
    else
        return ' &'
    endif
endfunction

" (Re)Generate the tags file for the current buffer's file.
function! s:manual_update_tags(bang) abort
    call s:update_tags(a:bang, 0)
endfunction

" (Re)Generate the tags file for a buffer that just go saved.
function! s:write_triggered_update_tags() abort
    if g:gutentags_enabled && g:gutentags_generate_on_write
        call s:update_tags(0, 1)
    endif
endfunction

" Update the tags file for the current buffer's file.
" write_mode:
"   0: update the tags file if it exists, generate it otherwise.
"   1: always generate (overwrite) the tags file.
"
" queue_mode:
"   0: if an update is already in progress, report it and abort.
"   1: if an update is already in progress, queue another one.
"
" An additional argument specifies where to write the tags file. If nothing
" is specified, it will go to the gutentags-defined file.
function! s:update_tags(write_mode, queue_mode, ...) abort
    " Figure out where to save.
    if a:0 == 1
        let l:tags_file = a:1
        let l:proj_dir = fnamemodify(a:1, ':h')
    else
        let l:tags_file = b:gutentags_file
        let l:proj_dir = b:gutentags_root
    endif

    " Check that there's not already an update in progress.
    let l:lock_file = l:tags_file . '.lock'
    if filereadable(l:lock_file)
        if a:queue_mode == 1
            let l:idx = index(s:update_queue, l:tags_file)
            if l:idx < 0
                call add(s:update_queue, l:tags_file)
            endif
            call s:trace("Tag file '" . l:tags_file . "' is already being updated. Queuing it up...")
            call s:trace("")
        else
            echom "gutentags: The tags file is already being updated, please try again later."
            echom ""
        endif
        return
    endif

    " Switch to the project root to make the command line smaller, and make
    " it possible to get the relative path of the filename to parse if we're
    " doing an incremental update.
    let l:prev_cwd = getcwd()
    let l:work_dir = fnamemodify(l:tags_file, ':h')
    execute "chdir " . l:work_dir

    try
        " Build the command line.
        let l:cmd = s:get_execute_cmd() . s:runner_exe
        let l:cmd .= ' -e "' . g:gutentags_executable . '"'
        let l:cmd .= ' -t "' . l:tags_file . '"'
        let l:cmd .= ' -p "' . l:proj_dir . '"'
        if a:write_mode == 0 && filereadable(l:tags_file)
            let l:full_path = expand('%:p')
            let l:cmd .= ' -s "' . l:full_path . '"'
        endif
        for ign in split(&wildignore, ',')
            let l:cmd .= ' -x ' . '"' . ign . '"'
        endfor
        for exc in g:gutentags_exclude
            let l:cmd .= ' -x ' . '"' . exc . '"'
        endfor
        if g:gutentags_pause_after_update
            let l:cmd .= ' -c'
        endif
        if len(g:gutentags_options_file)
            let l:cmd .= ' -o "' . g:gutentags_options_file . '"'
        endif
        if g:gutentags_trace
            if has('win32')
                let l:cmd .= ' -l "' . l:tags_file . '.log"'
            else
                let l:cmd .= ' > "' . l:tags_file . '.log" 2>&1'
            endif
        else
            if !has('win32')
                let l:cmd .= ' > /dev/null 2>&1'
            endif
        endif
        let l:cmd .= s:get_execute_cmd_suffix()

        call s:trace("Running: " . l:cmd)
        call s:trace("In:      " . l:work_dir)
        if !g:gutentags_fake
            " Run the background process.
            if !g:gutentags_trace
                silent execute l:cmd
            else
                execute l:cmd
            endif

            " Flag this tags file as being in progress
            let l:full_tags_file = fnamemodify(l:tags_file, ':p')
            let s:maybe_in_progress[l:full_tags_file] = localtime()
        else
            call s:trace("(fake... not actually running)")
        endif
        call s:trace("")
    finally
        " Restore the current directory...
        execute "chdir " . fnameescape(l:prev_cwd)
    endtry
endfunction

" }}}

" Manual Tagfile Generation {{{

function! s:generate_tags(bang, ...) abort
    call s:update_tags(1, 0, a:1)
endfunction

command! -bang -nargs=1 -complete=file GutentagsGenerate :call s:generate_tags(<bang>0, <f-args>)

" }}}

" Toggles and Miscellaneous Commands {{{

command! GutentagsToggleEnabled :let g:gutentags_enabled=!g:gutentags_enabled
command! GutentagsToggleTrace   :call gutentags#trace()
command! GutentagsUnlock        :call delete(b:gutentags_file . '.lock')

if g:gutentags_debug
    command! GutentagsToggleFake    :call gutentags#fake()
endif

" }}}

" Autoload Functions {{{

function! gutentags#rescan(...)
    if exists('b:gutentags_file')
        unlet b:gutentags_file
    endif
    if a:0 && a:1
        let l:trace_backup = g:gutentags_trace
        let l:gutentags_trace = 1
    endif
    call s:setup_gutentags()
    if a:0 && a:1
        let g:gutentags_trace = l:trace_backup
    endif
endfunction

function! gutentags#trace(...)
    let g:gutentags_trace = !g:gutentags_trace
    if a:0 > 0
        let g:gutentags_trace = a:1
    endif
    if g:gutentags_trace
        echom "gutentags: Tracing is enabled."
    else
        echom "gutentags: Tracing is disabled."
    endif
    echom ""
endfunction

function! gutentags#fake(...)
    let g:gutentags_fake = !g:gutentags_fake
    if a:0 > 0
        let g:gutentags_fake = a:1
    endif
    if g:gutentags_fake
        echom "gutentags: Now faking gutentags."
    else
        echom "gutentags: Now running gutentags for real."
    endif
    echom ""
endfunction

function! gutentags#inprogress()
    echom "gutentags: generations in progress:"
    for mip in keys(s:maybe_in_progress)
        echom mip
    endfor
    echom ""
endfunction

" }}}

" Statusline Functions {{{

" Prints whether a tag file is being generated right now for the current
" buffer in the status line.
"
" Arguments can be passed:
" - args 1 and 2 are the prefix and suffix, respectively, of whatever output,
"   if any, is going to be produced.
"   (defaults to empty strings)
" - arg 3 is the text to be shown if tags are currently being generated.
"   (defaults to 'TAGS')

function! gutentags#statusline(...) abort
    if !exists('b:gutentags_file')
        " This buffer doesn't have gutentags.
        return ''
    endif

    " Figure out what the user is customizing.
    let l:gen_msg = 'TAGS'
    if a:0 > 0
        let l:gen_msg = a:1
    endif

    " To make this function as fast as possible, we first check whether the
    " current buffer's tags file is 'maybe' being generated. This provides a
    " nice and quick bail out for 99.9% of cases before we need to this the
    " file-system to check the lock file.
    let l:abs_tag_file = fnamemodify(b:gutentags_file, ':p')
    let l:timestamp = get(s:maybe_in_progress, l:abs_tag_file)
    if l:timestamp == 0
        return ''
    endif
    " It's maybe generating! Check if the lock file is still there... but
    " don't do it too soon after the script was originally launched, because
    " there can be a race condition where we get here just before the script
    " had a chance to write the lock file.
    if (localtime() - l:timestamp) > 1 &&
                \!filereadable(l:abs_tag_file . '.lock')
        call remove(s:maybe_in_progress, l:abs_tag_file)
        return ''
    endif
    " It's still there! So probably `ctags` is still running...
    " (although there's a chance it crashed, or the script had a problem, and
    " the lock file has been left behind... we could try and run some
    " additional checks here to see if it's legitimately running, and
    " otherwise delete the lock file... maybe in the future...)
    return l:gen_msg
endfunction

" }}}

