" Pycscope module for Gutentags

if !has('cscope')
    throw "Can't enable the pycscope module for Gutentags, this Vim has ".
                \"no support for cscope files."
endif

" Global Options {{{

if !exists('g:gutentags_pycscope_executable')
    let g:gutentags_pycscope_executable = 'pycscope'
endif

if !exists('g:gutentags_pyscopefile')
    let g:gutentags_pyscopefile = 'pycscope.out'
endif

if !exists('g:gutentags_auto_add_pycscope')
    let g:gutentags_auto_add_pycscope = 1
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_pyscopedb')
let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'
let s:added_dbs = []

function! gutentags#pycscope#init(project_root) abort
    let l:dbfile_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_pyscopefile)
    let b:gutentags_files['pycscope'] = l:dbfile_path

    if g:gutentags_auto_add_pycscope && filereadable(l:dbfile_path)
        if index(s:added_dbs, l:dbfile_path) < 0
            call add(s:added_dbs, l:dbfile_path)
            silent! execute 'cs add ' . fnameescape(l:dbfile_path)
        endif
    endif
endfunction

function! gutentags#pycscope#generate(proj_dir, tags_file, gen_opts) abort
    let l:cmd = [s:runner_exe]
    let l:cmd += ['-e', g:gutentags_pycscope_executable]
    let l:cmd += ['-p', a:proj_dir]
    let l:cmd += ['-f', a:tags_file]
    let l:file_list_cmd =
        \ gutentags#get_project_file_list_cmd(a:proj_dir)
    if !empty(l:file_list_cmd)
        let l:cmd += ['-L', '"' . l:file_list_cmd . '"']
    endif
    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
		let l:job_opts = gutentags#build_default_job_options('pycscope')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        call gutentags#add_job('pycscope', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
endfunction

function! gutentags#pycscope#on_job_exit(job, exit_val) abort
    let l:job_idx = gutentags#find_job_index_by_data('pycscope', a:job)
    let l:dbfile_path = gutentags#get_job_tags_file('pycscope', l:job_idx)
    call gutentags#remove_job('pycscope', l:job_idx)

    if a:exit_val == 0
        if index(s:added_dbs, l:dbfile_path) < 0
            call add(s:added_dbs, l:dbfile_path)
            silent! execute 'cs add ' . fnameescape(l:dbfile_path)
        else
            silent! execute 'cs reset'
        endif
    else
        call gutentags#warning(
                    \"gutentags: pycscope job failed, returned: ".
                    \string(a:exit_val))
    endif
endfunction

" }}}

