" autotags.vim - Automatic ctags management for Vim
" Maintainer:   Ludovic Chabant <http://ludovic.chabant.com>
" Version:      0.0.1

" Globals {{{

if !exists('g:autotags_debug')
    let g:autotags_debug = 0
endif

if (exists('g:loaded_autotags') || &cp) && !g:autotags_debug
    finish
endif
if (exists('g:loaded_autotags') && g:autotags_debug)
    echom "Reloaded autotags."
endif
let g:loaded_autotags = 1

if !exists('g:autotags_trace')
    let g:autotags_trace = 1
endif

if !exists('g:autotags_fake')
    let g:autotags_fake = 0
endif

if !exists('g:autotags_background_update')
    let g:autotags_background_update = 1
endif

if !exists('g:autotags_enabled')
    let g:autotags_enabled = 1
endif

if !exists('g:autotags_executable')
    let g:autotags_executable = 'ctags'
endif

if !exists('g:autotags_tagfile')
    let g:autotags_tagfile = 'tags'
endif

if !exists('g:autotags_project_root')
    let g:autotags_project_root = []
endif
let g:autotags_project_root += ['.git', '.hg', '.bzr', '_darcs']

" }}}

" Utilities {{{

" Throw an exception message.
function! s:throw(message)
    let v:errmsg = "autotags: " . a:message
    throw v:errmsg
endfunction

" Prints a message if debug tracing is enabled.
function! s:trace(message, ...)
   if g:autotags_trace || (a:0 && a:1)
       let l:message = "autotags: " . a:message
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

" Autotags Setup {{{

" Finds the tag file path for the given current directory
" (typically the directory of the file being edited)
function! s:get_tagfile_for(path) abort
    let l:path = s:stripslash(a:path)
    let l:previous_path = ""
    while l:path != l:previous_path
        for root in g:autotags_project_root
            if getftype(l:path . '/' . root) != ""
                return simplify(fnamemodify(l:path, ':p') . g:autotags_tagfile)
            endif
        endfor
        let l:previous_path = l:path
        let l:path = fnamemodify(l:path, ':h')
    endwhile
    call s:throw("Can't figure out what tag file to use for: " . a:path)
endfunction

" Setup autotags for the current buffer.
function! s:setup_autotags() abort
    call s:trace("Scanning buffer '" . bufname('%') . "' for autotags setup...")
    if exists('b:autotags_file')
        return
    endif
    try
        let b:autotags_file = s:get_tagfile_for(expand('%:h'))
    catch /^autotags\:/
        return
    endtry

    call s:trace("Setting autotags for buffer '" . bufname('%') . "' with tagfile: " . b:autotags_file)

    let l:bn = bufnr('%')
    execute 'augroup autotags_buffer_' . l:bn
    execute '  autocmd!'
    execute '  autocmd BufWritePost <buffer=' . l:bn . '> if g:autotags_enabled|call s:update_tags(0, 1)|endif'
    execute 'augroup end'

    command! -buffer -bang AutotagsUpdate :call s:manual_update_tags(<bang>0)
endfunction

augroup autotags_detect
    autocmd!
    autocmd BufNewFile,BufReadPost *  call s:setup_autotags()
    autocmd VimEnter               *  if expand('<amatch>')==''|call s:setup_autotags()|endif
augroup end

" }}}

"  Tags File Management {{{

let s:runner_exe = expand('<sfile>:h:h') . '/plat/unix/update_tags.sh'
if has('win32')
    let s:runner_exe = expand('<sfile>:h:h') . '\plat\win32\update_tags.cmd'
endif

let s:update_queue = []

" Get how to execute an external command depending on debug settings.
function! s:get_execute_cmd() abort
    if has('win32')
        let l:cmd = '!start '
        if g:autotags_background_update
            let l:cmd .= '/b '
        endif
        return l:cmd
    else
        return '!'
    endif
endfunction

" (Re)Generate the tags file for the current buffer's file.
function! s:manual_update_tags(bang) abort
    call s:update_tags(a:bang, 0)
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
" is specified, it will go to the autotags-defined file.
function! s:update_tags(write_mode, queue_mode, ...) abort
    " Figure out where to save.
    let l:tags_file = 0
    if a:0 == 1
        let l:tags_file = a:1
    else
        let l:tags_file = b:autotags_file
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
            echom "autotags: The tags file is already being updated, please try again later."
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
        let l:cmd .= ' --exe "' . g:autotags_executable . '"'
        let l:cmd .= ' --tags "' . fnamemodify(l:tags_file, ':t') . '"'
        if a:write_mode == 0 && filereadable(l:tags_file)
            " CTags specifies paths relative to the tags file with a `./`
            " prefix, so we need to specify the same prefix otherwise it will
            " think those are different files and we'll end up with duplicate
            " entries.
            let l:rel_path = s:normalizepath('./' . expand('%:.'))
            let l:cmd .= ' --source "' . l:rel_path . '"'
        endif
        if g:autotags_trace
            let l:cmd .= ' --log "' . fnamemodify(l:tags_file, ':t') . '.log"'
        endif
        call s:trace("Running: " . l:cmd)
        call s:trace("In:      " . l:work_dir)
        if !g:autotags_fake
            if !g:autotags_trace
                silent execute l:cmd
            else
                execute l:cmd
            endif
        else
            call s:trace("(fake... not actually running)")
        endif
        call s:trace("")
    finally
        " Restore the current directory...
        execute "chdir " . l:prev_cwd
    endtry
endfunction

" }}}

" Manual Tagfile Generation {{{

function! s:generate_tags(bang, ...) abort
    call s:update_tags(1, 0, a:1)
endfunction

command! -bang -nargs=1 -complete=file AutotagsGenerate :call s:generate_tags(<bang>0, <f-args>)

" }}}

" Toggles {{{

command! AutotagsToggleEnabled :let g:autotags_enabled=!g:autotags_enabled
command! AutotagsToggleTrace   :call autotags#trace()
command! AutotagsToggleFake    :call autotags#fake()
command! AutotagsUnlock        :call delete(b:autotags_file . '.lock')

" }}}

" Autoload Functions {{{

function! autotags#rescan(...)
    if exists('b:autotags_file')
        unlet b:autotags_file
    endif
    if a:0 && a:1
        let l:trace_backup = g:autotags_trace
        let l:autotags_trace = 1
    endif
    call s:setup_autotags()
    if a:0 && a:1
        let g:autotags_trace = l:trace_backup
    endif
endfunction

function! autotags#trace(...)
    let g:autotags_trace = !g:autotags_trace
    if a:0 > 0
        let g:autotags_trace = a:1
    endif
    if g:autotags_trace
        echom "autotags: Tracing is enabled."
    else
        echom "autotags: Tracing is disabled."
    endif
    echom ""
endfunction

function! autotags#fake(...)
    let g:autotags_fake = !g:autotags_fake
    if a:0 > 0
        let g:autotags_fake = a:1
    endif
    if g:autotags_fake
        echom "autotags: Now faking autotags."
    else
        echom "autotags: Now running autotags for real."
    endif
    echom ""
endfunction

" }}}

