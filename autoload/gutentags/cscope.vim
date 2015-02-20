" Cscope module for Gutentags

if !has('cscope')
    throw "Can't enable the cscope module for Gutentags, this Vim has ".
                \"no support for cscope files."
endif

" Global Options {{{

if !exists('g:gutentags_cscope_executable')
    let g:gutentags_cscope_executable = 'cscope'
endif

if !exists('g:gutentags_scopefile')
    let g:gutentags_scopefile = 'cscope.out'
endif

if !exists('g:gutentags_auto_add_cscope')
    let g:gutentags_auto_add_cscope = 1
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_scopedb')
let s:added_dbs = []

function! gutentags#cscope#init(project_root) abort
    let l:dbfile_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_scopefile)
    let b:gutentags_files['cscope'] = l:dbfile_path

    if g:gutentags_auto_add_cscope && filereadable(l:dbfile_path)
        if index(s:added_dbs, l:dbfile_path) < 0
            call add(s:added_dbs, l:dbfile_path)
            execute 'cs add ' . fnameescape(l:dbfile_path)
        endif
    endif
endfunction

function! gutentags#cscope#generate(proj_dir, tags_file, write_mode) abort
    let l:cmd = gutentags#get_execute_cmd() . s:runner_exe
    let l:cmd .= ' -e ' . g:gutentags_cscope_executable
    let l:cmd .= ' -p ' . a:proj_dir
    let l:cmd .= ' -f ' . a:tags_file
    let l:cmd .= ' '
    let l:cmd .= gutentags#get_execute_cmd_suffix()

    call gutentags#trace("Running: " . l:cmd)
    call gutentags#trace("In:      " . getcwd())
    if !g:gutentags_fake
        if !g:gutentags_trace
            silent execute l:cmd
        else
            execute l:cmd
        endif

        let l:full_scopedb_file = fnamemodify(a:tags_file, ':p')
        call gutentags#add_progress('cscope', l:full_scopedb_file)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
    call gutentags#trace("")
endfunction

" }}}

