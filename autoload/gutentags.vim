" gutentags.vim - Automatic ctags management for Vim

" Utilities {{{

function! gutentags#chdir(path)
  if has('nvim')
    let chdir = haslocaldir() ? 'lcd' : haslocaldir(-1, 0) ? 'tcd' : 'cd'
  else
    let chdir = haslocaldir() ? 'lcd' : 'cd'
  endif
  execute chdir a:path
endfunction

" Throw an exception message.
function! gutentags#throw(message)
    throw "gutentags: " . a:message
endfunction

" Throw an exception message and set Vim's error message variable.
function! gutentags#throwerr(message)
    let v:errmsg = "gutentags: " . a:message
    throw v:errmsg
endfunction

" Prints a message if debug tracing is enabled.
function! gutentags#trace(message, ...)
   if g:gutentags_trace || (a:0 && a:1)
       let l:message = "gutentags: " . a:message
       echom l:message
   endif
endfunction

" Strips the ending slash in a path.
function! gutentags#stripslash(path)
    return fnamemodify(a:path, ':s?[/\\]$??')
endfunction

" Normalizes the slashes in a path.
function! gutentags#normalizepath(path)
    if exists('+shellslash') && &shellslash
        return substitute(a:path, '\v/', '\\', 'g')
    elseif has('win32')
        return substitute(a:path, '\v/', '\\', 'g')
    else
        return a:path
    endif
endfunction

" Shell-slashes the path (opposite of `normalizepath`).
function! gutentags#shellslash(path)
  if exists('+shellslash') && !&shellslash
    return substitute(a:path, '\v\\', '/', 'g')
  else
    return a:path
  endif
endfunction

" Gets a file path in the correct `plat` folder.
function! gutentags#get_plat_file(filename) abort
    return g:gutentags_plat_dir . a:filename . g:gutentags_script_ext
endfunction

" Gets a file path in the resource folder.
function! gutentags#get_res_file(filename) abort
    return g:gutentags_res_dir . a:filename
endfunction

" Returns whether a path is rooted.
if has('win32') || has('win64')
function! gutentags#is_path_rooted(path) abort
  return len(a:path) >= 2 && (
        \a:path[0] == '/' || a:path[0] == '\' || a:path[1] == ':')
endfunction
else
function! gutentags#is_path_rooted(path) abort
  return !empty(a:path) && a:path[0] == '/'
endfunction
endif

" }}}

" Gutentags Setup {{{

let s:known_files = []
let s:known_projects = {}

function! s:cache_project_root(path) abort
    let l:result = {}

    for proj_info in g:gutentags_project_info
        let l:filematch = get(proj_info, 'file', '')
        if l:filematch != '' && filereadable(a:path . '/'. l:filematch)
            let l:result = copy(proj_info)
            break
        endif

        let l:globmatch = get(proj_info, 'glob', '')
        if l:globmatch != '' && glob(a:path . '/' . l:globmatch) != ''
            let l:result = copy(proj_info)
            break
        endif
    endfor

    let s:known_projects[a:path] = l:result
endfunction

function! gutentags#validate_cmd(cmd) abort
    if !empty(a:cmd) && executable(split(a:cmd)[0])
        return a:cmd
    endif
    return ""
endfunction

function! gutentags#get_project_file_list_cmd(path) abort
    if type(g:gutentags_file_list_command) == type("")
        return gutentags#validate_cmd(g:gutentags_file_list_command)
    elseif type(g:gutentags_file_list_command) == type({})
        let l:markers = get(g:gutentags_file_list_command, 'markers', [])
        if type(l:markers) == type({})
            for [marker, file_list_cmd] in items(l:markers)
                if !empty(globpath(a:path, marker, 1))
                    return gutentags#validate_cmd(file_list_cmd)
                endif
            endfor
        endif
        return get(g:gutentags_file_list_command, 'default', "")
    endif
    return ""
endfunction

" Finds the first directory with a project marker by walking up from the given
" file path.
function! gutentags#get_project_root(path) abort
    if g:gutentags_project_root_finder != ''
        return call(g:gutentags_project_root_finder, [a:path])
    endif

    let l:path = gutentags#stripslash(a:path)
    let l:previous_path = ""
    let l:markers = g:gutentags_project_root[:]
    if exists('g:ctrlp_root_markers')
        for crm in g:ctrlp_root_markers
            if index(l:markers, crm) < 0
                call add(l:markers, crm)
            endif
        endfor
    endif
    while l:path != l:previous_path
        for root in l:markers
            if !empty(globpath(l:path, root, 1))
                let l:proj_dir = simplify(fnamemodify(l:path, ':p'))
                let l:proj_dir = gutentags#stripslash(l:proj_dir)
                if l:proj_dir == ''
                    call gutentags#trace("Found project marker '" . root .
                                \"' at the root of your file-system! " .
                                \" That's probably wrong, disabling " .
                                \"gutentags for this file...",
                                \1)
                    call gutentags#throw("Marker found at root, aborting.")
                endif
                for ign in g:gutentags_exclude_project_root
                    if l:proj_dir == ign
                        call gutentags#trace(
                                    \"Ignoring project root '" . l:proj_dir .
                                    \"' because it is in the list of ignored" .
                                    \" projects.")
                        call gutentags#throw("Ignore project: " . l:proj_dir)
                    endif
                endfor
                return l:proj_dir
            endif
        endfor
        let l:previous_path = l:path
        let l:path = fnamemodify(l:path, ':h')
    endwhile
    call gutentags#throw("Can't figure out what tag file to use for: " . a:path)
endfunction

" Get info on the project we're inside of.
function! gutentags#get_project_info(path) abort
    return get(s:known_projects, a:path, {})
endfunction

" Generate a path for a given filename in the cache directory.
function! gutentags#get_cachefile(root_dir, filename) abort
    if gutentags#is_path_rooted(a:filename)
        return a:filename
    endif
    let l:tag_path = gutentags#stripslash(a:root_dir) . '/' . a:filename
    if g:gutentags_cache_dir != ""
        " Put the tag file in the cache dir instead of inside the
        " project root.
        let l:tag_path = g:gutentags_cache_dir . '/' .
                    \tr(l:tag_path, '\/: ', '---_')
        let l:tag_path = substitute(l:tag_path, '/\-', '/', '')
    endif
    let l:tag_path = gutentags#normalizepath(l:tag_path)
    return l:tag_path
endfunction

" Setup gutentags for the current buffer.
function! gutentags#setup_gutentags() abort
    if exists('b:gutentags_files') && !g:gutentags_debug
        " This buffer already has gutentags support.
        return
    endif

    " Don't setup gutentags for anything that's not a normal buffer
    " (so don't do anything for help buffers and quickfix windows and
    "  other such things)
    " Also don't do anything for the default `[No Name]` buffer you get
    " after starting Vim.
    if &buftype != '' || 
          \(bufname('%') == '' && !g:gutentags_generate_on_empty_buffer)
        return
    endif

    " Let the user specify custom ways to disable Gutentags.
    if g:gutentags_init_user_func != '' &&
                \!call(g:gutentags_init_user_func, [expand('%:p')])
        call gutentags#trace("Ignoring '" . bufname('%') . "' because of " .
                    \"custom user function.")
        return
    endif

    " Try and find what tags file we should manage.
    call gutentags#trace("Scanning buffer '" . bufname('%') . "' for gutentags setup...")
    try
        let l:buf_dir = expand('%:p:h', 1)
        if g:gutentags_resolve_symlinks
            let l:buf_dir = fnamemodify(resolve(expand('%:p', 1)), ':p:h')
        endif
        if !exists('b:gutentags_root')
            let b:gutentags_root = gutentags#get_project_root(l:buf_dir)
        endif
        if filereadable(b:gutentags_root . '/.notags')
            call gutentags#trace("'.notags' file found... no gutentags support.")
            return
        endif

        if !has_key(s:known_projects, b:gutentags_root)
            call s:cache_project_root(b:gutentags_root)
        endif
        if g:gutentags_trace
            let l:projnfo = gutentags#get_project_info(b:gutentags_root)
            if l:projnfo != {}
                call gutentags#trace("Setting project type to ".l:projnfo['type'])
            else
                call gutentags#trace("No specific project type.")
            endif
        endif

        let b:gutentags_files = {}
        for module in g:gutentags_modules
            call call("gutentags#".module."#init", [b:gutentags_root])
        endfor
    catch /^gutentags\:/
        call gutentags#trace("No gutentags support for this buffer.")
        return
    endtry

    " We know what tags file to manage! Now set things up.
    call gutentags#trace("Setting gutentags for buffer '".bufname('%')."'")

    " Autocommands for updating the tags on save.
    " We need to pass the buffer number to the callback function in the rare
    " case that the current buffer is changed by another `BufWritePost`
    " callback. This will let us get that buffer's variables without causing
    " errors.
    let l:bn = bufnr('%')
    execute 'augroup gutentags_buffer_' . l:bn
    execute '  autocmd!'
    execute '  autocmd BufWritePost <buffer=' . l:bn . '> call s:write_triggered_update_tags(' . l:bn . ')'
    execute 'augroup end'

    " Miscellaneous commands.
    command! -buffer -bang GutentagsUpdate :call s:manual_update_tags(<bang>0)

    " Add these tags files to the known tags files.
    for module in keys(b:gutentags_files)
        let l:tagfile = b:gutentags_files[module]
        let l:found = index(s:known_files, l:tagfile)
        if l:found < 0
            call add(s:known_files, l:tagfile)

            " Generate this new file depending on settings and stuff.
            if g:gutentags_enabled
                if g:gutentags_generate_on_missing && !filereadable(l:tagfile)
                    call gutentags#trace("Generating missing tags file: " . l:tagfile)
                    call s:update_tags(l:bn, module, 1, 1)
                elseif g:gutentags_generate_on_new
                    call gutentags#trace("Generating tags file: " . l:tagfile)
                    call s:update_tags(l:bn, module, 1, 1)
                endif
            endif
        endif
    endfor
endfunction

" }}}

"  Tags File Management {{{

" List of queued-up jobs, and in-progress jobs, per module.
let s:update_queue = {}
let s:maybe_in_progress = {}
for module in g:gutentags_modules
    let s:update_queue[module] = []
    let s:maybe_in_progress[module] = {}
endfor

" Make a given file known as being currently generated or updated.
function! gutentags#add_progress(module, file) abort
    let l:abs_file = fnamemodify(a:file, ':p')
    let s:maybe_in_progress[a:module][l:abs_file] = localtime()
endfunction

" Get how to execute an external command depending on debug settings.
function! gutentags#get_execute_cmd() abort
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
function! gutentags#get_execute_cmd_suffix() abort
    if has('win32')
        return ''
    else
        return ' &'
    endif
endfunction

" (Re)Generate the tags file for the current buffer's file.
function! s:manual_update_tags(bang) abort
    let l:bn = bufnr('%')
    for module in g:gutentags_modules
        call s:update_tags(l:bn, module, a:bang, 0)
    endfor
    silent doautocmd User GutentagsUpdated
endfunction

" (Re)Generate the tags file for a buffer that just go saved.
function! s:write_triggered_update_tags(bufno) abort
    if g:gutentags_enabled && g:gutentags_generate_on_write
        for module in g:gutentags_modules
            call s:update_tags(a:bufno, module, 0, 2)
        endfor
    endif
    silent doautocmd User GutentagsUpdated
endfunction

" Update the tags file for the current buffer's file.
" write_mode:
"   0: update the tags file if it exists, generate it otherwise.
"   1: always generate (overwrite) the tags file.
"
" queue_mode:
"   0: if an update is already in progress, report it and abort.
"   1: if an update is already in progress, abort silently.
"   2: if an update is already in progress, queue another one.
function! s:update_tags(bufno, module, write_mode, queue_mode) abort
    " Figure out where to save.
    let l:buf_gutentags_files = getbufvar(a:bufno, 'gutentags_files')
    let l:tags_file = l:buf_gutentags_files[a:module]
    let l:proj_dir = getbufvar(a:bufno, 'gutentags_root')

    " Check that there's not already an update in progress.
    let l:lock_file = l:tags_file . '.lock'
    if filereadable(l:lock_file)
        if a:queue_mode == 2
            let l:idx = index(s:update_queue[a:module], l:tags_file)
            if l:idx < 0
                call add(s:update_queue[a:module], l:tags_file)
            endif
            call gutentags#trace("Tag file '" . l:tags_file . 
                        \"' is already being updated. Queuing it up...")
        elseif a:queue_mode == 1
            call gutentags#trace("Tag file '" . l:tags_file .
                        \"' is already being updated. Skipping...")
        elseif a:queue_mode == 0
            echom "gutentags: The tags file is already being updated, " .
                        \"please try again later."
        else
            call gutentags#throwerr("Unknown queue mode: " . a:queue_mode)
        endif
        return
    endif

    " Switch to the project root to make the command line smaller, and make
    " it possible to get the relative path of the filename to parse if we're
    " doing an incremental update.
    let l:prev_cwd = getcwd()
    call gutentags#chdir(fnameescape(l:proj_dir))
    try
        call call("gutentags#".a:module."#generate",
                    \[l:proj_dir, l:tags_file, a:write_mode])
    catch /^gutentags\:/
        echom "Error while generating ".a:module." file:"
        echom v:exception
    finally
        " Restore the current directory...
        call gutentags#chdir(fnameescape(l:prev_cwd))
    endtry
endfunction

" }}}

" Utility Functions {{{

function! gutentags#rescan(...)
    if exists('b:gutentags_files')
        unlet b:gutentags_files
    endif
    if a:0 && a:1
        let l:trace_backup = g:gutentags_trace
        let l:gutentags_trace = 1
    endif
    call gutentags#setup_gutentags()
    if a:0 && a:1
        let g:gutentags_trace = l:trace_backup
    endif
endfunction

function! gutentags#delete_lock_files() abort
    if exists('b:gutentags_files')
        for tagfile in values(b:gutentags_files)
            silent call delete(tagfile.'.lock')
        endfor
    endif
endfunction

function! gutentags#toggletrace(...)
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
    for mod_name in keys(s:maybe_in_progress)
        for mib in keys(s:maybe_in_progress[mod_name])
            echom mod_name.":  ".mib
        endfor
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
    if !exists('b:gutentags_files')
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
    let l:modules_in_progress = []
    for module in keys(b:gutentags_files)
        let l:abs_tag_file = fnamemodify(b:gutentags_files[module], ':p')
        let l:progress_queue = s:maybe_in_progress[module]
        let l:timestamp = get(l:progress_queue, l:abs_tag_file)
        if l:timestamp == 0
            continue
        endif
        " It's maybe generating! Check if the lock file is still there... but
        " don't do it too soon after the script was originally launched, because
        " there can be a race condition where we get here just before the script
        " had a chance to write the lock file.
        if (localtime() - l:timestamp) > 1 &&
                    \!filereadable(l:abs_tag_file . '.lock')
            call remove(l:progress_queue, l:abs_tag_file)
            continue
        endif
        call add(l:modules_in_progress, module)
    endfor

    if len(l:modules_in_progress) == 0
        return ''
    endif

    " It's still there! So probably `ctags` is still running...
    " (although there's a chance it crashed, or the script had a problem, and
    " the lock file has been left behind... we could try and run some
    " additional checks here to see if it's legitimately running, and
    " otherwise delete the lock file... maybe in the future...)
    let l:gen_msg .= '['.join(l:modules_in_progress, ',').']'
    return l:gen_msg
endfunction

" }}}

