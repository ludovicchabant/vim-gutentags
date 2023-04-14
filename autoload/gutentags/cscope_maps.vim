" cscope_maps module for Gutentags

if !has('nvim') || !exists(":Cscope")
    throw "Can't enable the cscope_maps module for Gutentags, this Vim has ".
                \"no support for cscope_maps files."
endif

" Global Options {{{

if !exists('g:gutentags_cscope_executable_maps')
    let g:gutentags_cscope_executable_maps = 'cscope'
endif

if !exists('g:gutentags_scopefile_maps')
    let g:gutentags_scopefile_maps = 'cscope.out'
endif

if !exists('g:gutentags_cscope_build_inverted_index_maps')
    let g:gutentags_cscope_build_inverted_index_maps = 0
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_scopedb')
let s:unix_redir = (&shellredir =~# '%s') ? &shellredir : &shellredir . ' %s'
let s:added_dbs = []

function! gutentags#cscope_maps#init(project_root) abort
    let l:dbfile_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_scopefile_maps)
    let b:gutentags_files['cscope_maps'] = l:dbfile_path
endfunction

function! gutentags#cscope_maps#generate(proj_dir, tags_file, gen_opts) abort
    let l:cmd = [s:runner_exe]
    let l:cmd += ['-e', g:gutentags_cscope_executable_maps]
    let l:cmd += ['-p', a:proj_dir]
    let l:cmd += ['-f', a:tags_file]
    let l:file_list_cmd =
        \ gutentags#get_project_file_list_cmd(a:proj_dir)
    if !empty(l:file_list_cmd)
        let l:cmd += ['-L', '"' . l:file_list_cmd . '"']
    endif
    if g:gutentags_cscope_build_inverted_index_maps
        let l:cmd += ['-I']
    endif
    let l:cmd = gutentags#make_args(l:cmd)

    call gutentags#trace("Running: " . string(l:cmd))
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
        let l:job_opts = gutentags#build_default_job_options('cscope_maps')
        let l:job = gutentags#start_job(l:cmd, l:job_opts)
        " Change cscope_maps db_file to gutentags' tags_file
        " Useful for when g:gutentags_cache_dir is used.
        let g:cscope_maps_db_file = a:tags_file
        call gutentags#add_job('cscope_maps', a:tags_file, l:job)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
endfunction

function! gutentags#cscope_maps#on_job_exit(job, exit_val) abort
    let l:job_idx = gutentags#find_job_index_by_data('cscope_maps', a:job)
    let l:dbfile_path = gutentags#get_job_tags_file('cscope_maps', l:job_idx)
    call gutentags#remove_job('cscope_maps', l:job_idx)

    if a:exit_val == 0
        call gutentags#trace("NOOP! cscope_maps does not need add or reset command")
    elseif !g:__gutentags_vim_is_leaving
        call gutentags#warning(
                    \"cscope job failed, returned: ".
                    \string(a:exit_val))
    endif
endfunction

" }}}

