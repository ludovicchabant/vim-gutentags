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

" Show an error message.
function! gutentags#error(message)
    let v:errmsg = "gutentags: " . a:message
    echoerr v:errmsg
endfunction

" Show a warning message.
function! gutentags#warning(message)
    echohl WarningMsg
    echom "gutentags: " . a:message
    echohl None
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

" Makes sure a given command starts with an executable that's in the PATH.
function! gutentags#validate_cmd(cmd) abort
    if !empty(a:cmd) && executable(split(a:cmd)[0])
        return a:cmd
    endif
    return ""
endfunction

" Makes an appropriate command line for use with `job_start` by converting
" a list of possibly quoted arguments into a single string on Windows, or
" into a list of unquoted arguments on Unix/Mac.
if has('win32') || has('win64')
    function! gutentags#make_args(cmd) abort
        return join(a:cmd, ' ')
    endfunction
else
    function! gutentags#make_args(cmd) abort
        let l:outcmd = []
        for cmdarg in a:cmd
            " Thanks Vimscript... you can use negative integers for strings
            " in the slice notation, but not for indexing characters :(
            let l:arglen = strlen(cmdarg)
            if (cmdarg[0] == '"' && cmdarg[l:arglen - 1] == '"') || 
                        \(cmdarg[0] == "'" && cmdarg[l:arglen - 1] == "'")
                call add(l:outcmd, cmdarg[1:-2])
            else
                call add(l:outcmd, cmdarg)
            endif
        endfor
        return l:outcmd
    endfunction
endif

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

"  Job Management {{{

" List of queued-up jobs, and in-progress jobs, per module.
let s:update_queue = {}
let s:update_in_progress = {}
for module in g:gutentags_modules
    let s:update_queue[module] = []
    let s:update_in_progress[module] = []
endfor

function! gutentags#add_job(module, tags_file, data) abort
    call add(s:update_in_progress[a:module], [a:tags_file, a:data])
endfunction

function! gutentags#find_job_index_by_tags_file(module, tags_file) abort
    let l:idx = -1
    for upd_info in s:update_in_progress[a:module]
        let l:idx += 1
        if upd_info[0] == a:tags_file
            return l:idx
        endif
    endfor
    return -1
endfunction

function! gutentags#find_job_index_by_data(module, data) abort
    let l:idx = -1
    for upd_info in s:update_in_progress[a:module]
        let l:idx += 1
        if upd_info[1] == a:data
            return l:idx
        endif
    endfor
    return -1
endfunction

function! gutentags#get_job_tags_file(module, job_idx) abort
    return s:update_in_progress[a:module][a:job_idx][0]
endfunction

function! gutentags#get_job_data(module, job_idx) abort
    return s:update_in_progress[a:module][a:job_idx][1]
endfunction

function! gutentags#remove_job(module, job_idx) abort
    let l:tags_file = s:update_in_progress[a:module][a:job_idx][0]
    call remove(s:update_in_progress[a:module], a:job_idx)

    " Run the user callback for finished jobs.
    silent doautocmd User GutentagsUpdated

    " See if we had any more updates queued up for this.
    let l:qu_idx = -1
    for qu_info in s:update_queue[a:module]
        let l:qu_idx += 1
        if qu_info[0] == l:tags_file
            break
        endif
    endfor
    if l:qu_idx >= 0
        let l:qu_info = s:update_queue[a:module][l:qu_idx]
        call remove(s:update_queue[a:module], l:qu_idx)

        if bufexists(l:qu_info[1])
            call gutentags#trace("Finished ".a:module." job, ".
                        \"running queued update for '".l:tags_file."'.")
            call s:update_tags(l:qu_info[1], a:module, l:qu_info[2], 2)
        else
            call gutentags#trace("Finished ".a:module." job, ".
                        \"but skipping queued update for '".l:tags_file."' ".
                        \"because originating buffer doesn't exist anymore.")
        endif
    else
        call gutentags#trace("Finished ".a:module." job.")
    endif
endfunction

function! gutentags#remove_job_by_data(module, data) abort
    let l:idx = gutentags#find_job_index_by_data(a:module, a:data)
    call gutentags#remove_job(a:module, l:idx)
endfunction

" }}}

"  Tags File Management {{{

" (Re)Generate the tags file for the current buffer's file.
function! s:manual_update_tags(bang) abort
    let l:bn = bufnr('%')
    for module in g:gutentags_modules
        call s:update_tags(l:bn, module, a:bang, 0)
    endfor
    silent doautocmd User GutentagsUpdating
endfunction

" (Re)Generate the tags file for a buffer that just go saved.
function! s:write_triggered_update_tags(bufno) abort
    if g:gutentags_enabled && g:gutentags_generate_on_write
        for module in g:gutentags_modules
            call s:update_tags(a:bufno, module, 0, 2)
        endfor
    endif
    silent doautocmd User GutentagsUpdating
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
    let l:in_progress_idx = gutentags#find_job_index_by_tags_file(
                \a:module, l:tags_file)
    if l:in_progress_idx >= 0
        if a:queue_mode == 2
            let l:needs_queuing = 1
            for qu_info in s:update_queue[a:module]
                if qu_info[0] == l:tags_file
                    let l:needs_queuing = 0
                    break
                endif
            endfor
            if l:needs_queuing
                call add(s:update_queue[a:module], 
                            \[l:tags_file, a:bufno, a:write_mode])
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
            call gutentags#throw("Unknown queue mode: " . a:queue_mode)
        endif

        " Don't update the tags right now.
        return
    endif

    " Switch to the project root to make the command line smaller, and make
    " it possible to get the relative path of the filename to parse if we're
    " doing an incremental update.
    let l:prev_cwd = getcwd()
    call gutentags#chdir(fnameescape(l:proj_dir))
    try
        call call("gutentags#".a:module."#generate",
                    \[l:proj_dir, l:tags_file,
                    \ {
                    \   'write_mode': a:write_mode,
                    \ }])
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

function! gutentags#default_io_cb(chan, msg) abort
	call gutentags#trace(a:msg)
endfunction

if has('nvim')
    " Neovim job API.
    function! s:nvim_job_exit_wrapper(real_cb, job, exit_code, event_type) abort
        call call(a:real_cb, [a:job, a:exit_code])
    endfunction

    function! s:nvim_job_out_wrapper(real_cb, job, lines, event_type) abort
        call call(a:real_cb, [a:job, a:lines])
    endfunction

    function! gutentags#build_default_job_options(module) abort
        let l:job_opts = {
                    \'on_exit': function(
                    \    '<SID>nvim_job_exit_wrapper',
                    \    ['gutentags#'.a:module.'#on_job_exit']),
                    \'on_stdout': function(
                    \    '<SID>nvim_job_out_wrapper',
                    \    ['gutentags#default_io_cb']),
                    \'on_stderr': function(
                    \    '<SID>nvim_job_out_wrapper',
                    \    ['gutentags#default_io_cb'])
                    \}
        return l:job_opts
    endfunction

    function! gutentags#start_job(cmd, opts) abort
        return jobstart(a:cmd, a:opts)
    endfunction
else
    " Vim8 job API.
    function! gutentags#build_default_job_options(module) abort
        let l:job_opts = {
                    \'exit_cb': 'gutentags#'.a:module.'#on_job_exit',
                    \'out_cb': 'gutentags#default_io_cb',
                    \'err_cb': 'gutentags#default_io_cb'
                    \}
        return l:job_opts
    endfunction

    function! gutentags#start_job(cmd, opts) abort
        return job_start(a:cmd, a:opts)
    endfunction
endif

" Returns which modules are currently generating something for the
" current buffer.
function! gutentags#inprogress()
   " Does this buffer have gutentags enabled?
   if !exists('b:gutentags_files')
      return []
   endif

   " Find any module that has a job in progress for any of this buffer's
   " tags files.
   let l:modules_in_progress = []
   for [module, tags_file] in items(b:gutentags_files)
      let l:jobidx = gutentags#find_job_index_by_tags_file(module, tags_file)
      if l:jobidx >= 0
         call add(l:modules_in_progress, module)
      endif
   endfor
   return l:modules_in_progress
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
"   (defaults to the name(s) of the modules currently generating).

function! gutentags#statusline(...) abort
    let l:modules_in_progress = gutentags#inprogress()
    if empty(l:modules_in_progress)
       return ''
    endif

    let l:prefix = ''
    let l:suffix = ''
    if a:0 > 0
       let l:prefix = a:1
    endif
    if a:0 > 1
       let l:suffix = a:2
    endif

    if a:0 > 2
       let l:genmsg = a:3
    else
       let l:genmsg = join(l:modules_in_progress, ',')
    endif

    return l:prefix.l:genmsg.l:suffix
endfunction

" Same as `gutentags#statusline`, but the only parameter is a `Funcref` or
" function name that will get passed the list of modules currently generating
" something. This formatter function should return the string to display in
" the status line.

function! gutentags#statusline_cb(fmt_cb, ...) abort
    let l:modules_in_progress = gutentags#inprogress()

    if (a:0 == 0 || !a:1) && empty(l:modules_in_progress)
       return ''
    endif

    return call(a:fmt_cb, [l:modules_in_progress])
endfunction

" }}}

