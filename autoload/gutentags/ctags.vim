" Ctags module for Gutentags

" Global Options {{{

let g:gutentags_ctags_executable = get(g:, 'gutentags_ctags_executable', 'ctags')
let g:gutentags_ctags_tagfile = get(g:, 'gutentags_ctags_tagfile', 'tags')
let g:gutentags_ctags_auto_set_tags = get(g:, 'gutentags_ctags_auto_set_tags', 1)

let g:gutentags_ctags_options_file = get(g:, 'gutentags_ctags_options_file', '.gutctags')
let g:gutentags_ctags_check_tagfile = get(g:, 'gutentags_ctags_check_tagfile', 0)
let g:gutentags_ctags_extra_args = get(g:, 'gutentags_ctags_extra_args', [])
let g:gutentags_ctags_post_process_cmd = get(g:, 'gutentags_ctags_post_process_cmd', '')

let g:gutentags_ctags_exclude = get(g:, 'gutentags_ctags_exclude', [])
let g:gutentags_ctags_exclude_wildignore = get(g:, 'gutentags_ctags_exclude_wildignore', 1)

" Backwards compatibility.
function! s:_handleOldOptions() abort
    let l:renamed_options = {
                \'gutentags_exclude': 'gutentags_ctags_exclude',
                \'gutentags_tagfile': 'gutentags_ctags_tagfile',
                \'gutentags_auto_set_tags': 'gutentags_ctags_auto_set_tags'
                \}
    for key in keys(l:renamed_options)
        if exists('g:'.key)
            let newname = l:renamed_options[key]
            echom "gutentags: Option 'g:'".key." has been renamed to ".
                        \"'g:'".newname." Please update your vimrc."
            let g:[newname] = g:[key]
        endif
    endfor
endfunction
call s:_handleOldOptions()
" }}}

" Gutentags Module Interface {{{

let s:did_check_exe = 0
let s:runner_exe = gutentags#get_plat_file('update_tags')
let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'

function! gutentags#ctags#init(project_root) abort
    " Figure out the path to the tags file.
    " Check the old name for this option, too, before falling back to the
    " globally defined name.
    let l:tagfile = getbufvar("", 'gutentags_ctags_tagfile',
                \getbufvar("", 'gutentags_tagfile', 
                \g:gutentags_ctags_tagfile))
    let b:gutentags_files['ctags'] = gutentags#get_cachefile(
                \a:project_root, l:tagfile)

    " Set the tags file for Vim to use.
    if g:gutentags_ctags_auto_set_tags
        execute 'setlocal tags^=' . fnameescape(b:gutentags_files['ctags'])
    endif

    " Check if the ctags executable exists.
    if s:did_check_exe == 0
        if g:gutentags_enabled && executable(expand(g:gutentags_ctags_executable, 1)) == 0
            let g:gutentags_enabled = 0
            echoerr "Executable '".g:gutentags_ctags_executable."' can't be found. "
                        \."Gutentags will be disabled. You can re-enable it by "
                        \."setting g:gutentags_enabled back to 1."
        endif
        let s:did_check_exe = 1
    endif
endfunction

function! gutentags#ctags#generate(proj_dir, tags_file, gen_opts) abort
    let l:write_mode = a:gen_opts['write_mode']

    let l:tags_file_exists = filereadable(a:tags_file)
    let l:tags_file_relative = fnamemodify(a:tags_file, ':.')
    let l:tags_file_is_local = len(l:tags_file_relative) < len(a:tags_file)

    if l:tags_file_exists && g:gutentags_ctags_check_tagfile
        let l:first_lines = readfile(a:tags_file, '', 1)
        if len(l:first_lines) == 0 || stridx(l:first_lines[0], '!_TAG_') != 0
            call gutentags#throw(
                        \"File ".a:tags_file." doesn't appear to be ".
                        \"a ctags file. Please delete it and run ".
                        \":GutentagsUpdate!.")
            return
        endif
    endif

    if empty(g:gutentags_cache_dir) && l:tags_file_is_local
        " If we don't use the cache directory, we can pass relative paths
        " around.
        "
        " Note that if we don't do this and pass a full path for the project
        " root, some `ctags` implementations like Exhuberant Ctags can get
        " confused if the paths have spaces -- but not if you're *in* the root 
        " directory, for some reason... (which we are, our caller in
        " `autoload/gutentags.vim` changed it).
        let l:actual_proj_dir = '.'
        let l:actual_tags_file = l:tags_file_relative
    else
        " else: the tags file goes in a cache directory, so we need to specify
        " all the paths absolutely for `ctags` to do its job correctly.
        let l:actual_proj_dir = a:proj_dir
        let l:actual_tags_file = a:tags_file
    endif

    " Build the command line.
    let l:cmd = [s:runner_exe]
    let l:cmd += ['-e', '"' . s:get_ctags_executable(a:proj_dir) . '"']
    let l:cmd += ['-t', '"' . l:actual_tags_file . '"']
    let l:cmd += ['-p', '"' . l:actual_proj_dir . '"']
    if l:write_mode == 0 && l:tags_file_exists
        let l:cur_file_path = expand('%:p')
        if empty(g:gutentags_cache_dir) && l:tags_file_is_local
            let l:cur_file_path = fnamemodify(l:cur_file_path, ':.')
        endif
        let l:cmd += ['-s', '"' . l:cur_file_path . '"']
    else
        let l:file_list_cmd = gutentags#get_project_file_list_cmd(l:actual_proj_dir)
        if !empty(l:file_list_cmd)
            if match(l:file_list_cmd, '///') > 0
                let l:suffopts = split(l:file_list_cmd, '///')
                let l:suffoptstr = l:suffopts[1]
                let l:file_list_cmd = l:suffopts[0]
                if l:suffoptstr == 'absolute'
                    let l:cmd += ['-A']
                endif
            endif
            let l:cmd += ['-L', '"' . l:file_list_cmd. '"']
        endif
    endif
    if empty(get(l:, 'file_list_cmd', ''))
        " Pass the Gutentags recursive options file before the project
        " options file, so that users can override --recursive.
        " Omit --recursive if this project uses a file list command.
        let l:cmd += ['-o', '"' . gutentags#get_res_file('ctags_recursive.options') . '"']
    endif
    if !empty(g:gutentags_ctags_extra_args)
        let l:cmd += ['-O', shellescape(join(g:gutentags_ctags_extra_args))]
    endif
    if !empty(g:gutentags_ctags_post_process_cmd)
        let l:cmd += ['-P', shellescape(g:gutentags_ctags_post_process_cmd)]
    endif
    let l:proj_options_file = a:proj_dir . '/' .
                \g:gutentags_ctags_options_file
    if filereadable(l:proj_options_file)
        let l:proj_options_file = s:process_options_file(
                    \a:proj_dir, l:proj_options_file)
        let l:cmd += ['-o', '"' . l:proj_options_file . '"']
    endif
    if g:gutentags_ctags_exclude_wildignore
        for ign in split(&wildignore, ',')
            let l:cmd += ['-x', shellescape(ign, 1)]
        endfor
    endif
    for exc in g:gutentags_ctags_exclude
        let l:cmd += ['-x', '"' . exc . '"']
    endfor
    if g:gutentags_pause_after_update
        let l:cmd += ['-c']
    endif
    if g:gutentags_trace
        let l:cmd += ['-l', '"' . l:actual_tags_file . '.log"']
    endif
    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
		let l:job_opts = gutentags#build_default_job_options('ctags')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        call gutentags#add_job('ctags', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
endfunction

function! gutentags#ctags#on_job_exit(job, exit_val) abort
    call gutentags#remove_job_by_data('ctags', a:job)

    if a:exit_val != 0
        call gutentags#warning("gutentags: ctags job failed, returned: ".
                    \string(a:exit_val))
    endif
endfunction

" }}}

" Utilities {{{

" Get final ctags executable depending whether a filetype one is defined
function! s:get_ctags_executable(proj_dir) abort
    "Only consider the main filetype in cases like 'python.django'
    let l:ftype = get(split(&filetype, '\.'), 0, '')
    let l:proj_info = gutentags#get_project_info(a:proj_dir)
    let l:type = get(l:proj_info, 'type', l:ftype)
    let exepath = exists('g:gutentags_ctags_executable_{l:type}')
        \ ? g:gutentags_ctags_executable_{l:type} : g:gutentags_ctags_executable
    return expand(exepath, 1)
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
