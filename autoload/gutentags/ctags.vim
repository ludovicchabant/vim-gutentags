" Ctags module for Gutentags

" Global Options {{{

if !exists('g:gutentags_ctags_executable')
    let g:gutentags_ctags_executable = 'ctags'
endif

if !exists('g:gutentags_ctags_filename')
    let g:gutentags_ctags_filename = get(g:, 'gutentags_tagfile', 'tags')
endif
function! gutentags#ctags#filename()
    return g:gutentags_ctags_filename
endfunction

if !exists('g:gutentags_auto_set_tags')
    let g:gutentags_auto_set_tags = 1
endif

if !exists('g:gutentags_ctags_options_file')
    let g:gutentags_ctags_options_file = '.gutctags'
endif

if !exists('g:gutentags_ctags_check_tagfile')
    let g:gutentags_ctags_check_tagfile = 0
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_tags')
let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'

function! gutentags#ctags#init(project_root) abort
    " Figure out the path to the tags file.
    let b:gutentags_files['ctags'] = gutentags#get_cachefile(
                \a:project_root, g:gutentags_ctags_filename)

    " Set the tags file for Vim to use.
    if g:gutentags_auto_set_tags
        execute 'setlocal tags^=' . fnameescape(b:gutentags_files['ctags'])
    endif

    " Check if the ctags executable exists.
    if g:gutentags_enabled && executable(g:gutentags_ctags_executable) == 0
        let g:gutentags_enabled = 0
        echoerr "Executable '".g:gutentags_ctags_executable."' can't be found. "
                    \."Gutentags will be disabled. You can re-enable it by "
                    \."setting g:gutentags_enabled back to 1."
    endif
endfunction

function! gutentags#ctags#generate(proj_dir, tags_file, write_mode) abort
    " Get to the tags file directory because ctags is finicky about
    " these things.
    let l:prev_cwd = getcwd()
    let l:tags_file_exists = filereadable(a:tags_file)

    if l:tags_file_exists && g:gutentags_ctags_check_tagfile
        let l:first_lines = readfile(a:tags_file, '', 1)
        if len(l:first_lines) == 0 || stridx(l:first_lines[0], '!_TAG_') != 0
            call gutentags#throw("File ".a:tags_file." doesn't appear to be ".
                        \"a ctags file. Please delete it and run ".
                        \":GutentagsUpdate!.")
            return
        endif
    endif

    if empty(g:gutentags_cache_dir)
        " If we don't use the cache directory, let's just use the tag filename
        " as specified by the user, and change the working directory to the
        " project root.
        " Note that if we don't do this and pass a full path, `ctags` gets
        " confused if the paths have spaces -- but not if you're *in* the
        " root directory.
        let l:actual_proj_dir = '.'
        let l:actual_tags_file = g:gutentags_ctags_filename
        execute "chdir " . fnameescape(a:proj_dir)
    else
        " else: the tags file goes in a cache directory, so we need to specify
        " all the paths absolutely for `ctags` to do its job correctly.
        let l:actual_proj_dir = a:proj_dir
        let l:actual_tags_file = a:tags_file
    endif

    try
        " Build the command line.
        let l:cmd = gutentags#get_execute_cmd() . s:runner_exe
        let l:cmd .= ' -e "' . s:get_ctags_executable(a:proj_dir) . '"'
        let l:cmd .= ' -t "' . l:actual_tags_file . '"'
        let l:cmd .= ' -p "' . l:actual_proj_dir . '"'
        if a:write_mode == 0 && l:tags_file_exists
            let l:full_path = expand('%:p')
            let l:cmd .= ' -s "' . l:full_path . '"'
        endif
        " Pass the Gutentags options file first, and then the project specific
        " one, so that users can override the default behaviour.
        let l:cmd .= ' -o "' . gutentags#get_res_file('ctags.options') . '"'
        let l:proj_options_file = a:proj_dir . '/' .
                    \g:gutentags_ctags_options_file
        if filereadable(l:proj_options_file)
            let l:proj_options_file = s:process_options_file(
                        \a:proj_dir, l:proj_options_file)
            let l:cmd .= ' -o "' . l:proj_options_file . '"'
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
        if g:gutentags_trace
            if has('win32')
                let l:cmd .= ' -l "' . l:actual_tags_file . '.log"'
            else
                let l:cmd .= ' ' . printf(s:unix_redir, '"' . l:actual_tags_file . '.log"')
            endif
        else
            if !has('win32')
                let l:cmd .= ' ' . printf(s:unix_redir, '/dev/null')
            endif
        endif
        let l:cmd .= gutentags#get_execute_cmd_suffix()

        call gutentags#trace("Running: " . l:cmd)
        call gutentags#trace("In:      " . getcwd())
        if !g:gutentags_fake
            " Run the background process.
            if !g:gutentags_trace
                silent execute l:cmd
            else
                execute l:cmd
            endif

            " Flag this tags file as being in progress
            let l:full_tags_file = fnamemodify(a:tags_file, ':p')
            call gutentags#add_progress('ctags', l:full_tags_file)
        else
            call gutentags#trace("(fake... not actually running)")
        endif
        call gutentags#trace("")
    finally
        " Restore the previous working directory.
        execute "chdir " . fnameescape(l:prev_cwd)
    endtry
endfunction

" }}}

" Utilities {{{

" Get final ctags executable depending whether a filetype one is defined
function! s:get_ctags_executable(proj_dir) abort
    "Only consider the main filetype in cases like 'python.django'
    let l:ftype = get(split(&filetype, '\.'), 0, '')
    let l:proj_info = gutentags#get_project_info(a:proj_dir)
    let l:type = get(l:proj_info, 'type', l:ftype)
    if exists('g:gutentags_ctags_executable_{l:type}')
        return g:gutentags_ctags_executable_{l:type}
    else
        return g:gutentags_ctags_executable
    endif
endfunction

function! s:process_options_file(proj_dir, path) abort
    if empty(g:gutentags_cache_dir)
        " If we're not using a cache directory to store tag files, we can
        " use the options file straight away.
        return a:path
    endif

    " See if we need to process the options file.
    let l:do_process = 0
    let l:proj_dir = gutentags#stripslash(a:proj_dir)
    let l:out_path = gutentags#get_cachefile(l:proj_dir, 'options')
    if !filereadable(l:out_path)
        call gutentags#trace("Processing options file '".a:path."' because ".
                    \"it hasn't been processed yet.")
        let l:do_process = 1
    elseif getftime(a:path) > getftime(l:out_path)
        call gutentags#trace("Processing options file '".a:path."' because ".
                    \"it has changed.")
        let l:do_process = 1
    endif
    if l:do_process == 0
        " Nothing's changed, return the existing processed version of the
        " options file.
        return l:out_path
    endif

    " We have to process the options file. Right now this only means capturing
    " all the 'exclude' rules, and rewrite them to make them absolute.
    "
    " This is because since `ctags` is run with absolute paths (because we
    " want the tag file to be in a cache directory), it will do its path
    " matching with absolute paths too, so the exclude rules need to be
    " absolute.
    let l:lines = readfile(a:path)
    let l:outlines = []
    for line in l:lines
        let l:exarg_idx = matchend(line, '\v^\-\-exclude=')
        if l:exarg_idx < 0
            call add(l:outlines, line)
            continue
        endif

        " Don't convert things that don't look like paths.
        let l:exarg = strpart(line, l:exarg_idx + 1)
        let l:do_convert = 1
        if l:exarg[0] == '@'   " Manifest file path
            let l:do_convert = 0
        endif
        if stridx(l:exarg, '/') < 0 && stridx(l:exarg, '\\') < 0   " Filename
            let l:do_convert = 0
        endif
        if l:do_convert == 0
            call add(l:outlines, line)
            continue
        endif

        let l:fullp = l:proj_dir . gutentags#normalizepath('/'.l:exarg)
        let l:ol = '--exclude='.l:fullp
        call add(l:outlines, l:ol)
    endfor

    call writefile(l:outlines, l:out_path)
    return l:out_path
endfunction

" }}}
