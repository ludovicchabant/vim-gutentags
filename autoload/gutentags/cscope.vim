" Cscope module for Gutentags

if !has('cscope')
    throw "Can't enable the cscope module for Gutentags, this Vim has ".
                \"no support for cscope files."
endif

" Global Options {{{

if !exists('g:gutentags_cscope_executable')
    let g:gutentags_cscope_executable = 'cscope'
endif

if !exists('g:gutentags_cscope_filename')
    let g:gutentags_cscope_filename = get(g:, 'gutentags_scopefile', 'cscope.out')
endif
function! gutentags#cscope#filename()
    return g:gutentags_cscope_filename
endfunction

if !exists('g:gutentags_auto_add_cscope')
    let g:gutentags_auto_add_cscope = 1
endif

" }}}

" Gutentags Module Interface {{{

let s:runner_exe = gutentags#get_plat_file('update_scopedb')
let s:added_dbs = []

function! gutentags#cscope#init(project_root) abort
    let l:dbfile_path = gutentags#get_cachefile(
                \a:project_root, g:gutentags_cscope_filename)
    let b:gutentags_files['cscope'] = l:dbfile_path

    if g:gutentags_auto_add_cscope && filereadable(l:dbfile_path)
        if index(s:added_dbs, l:dbfile_path) < 0
            call add(s:added_dbs, l:dbfile_path)
            execute 'cs add ' . fnameescape(l:dbfile_path)
        endif
    endif
endfunction

function! gutentags#cscope#command_terminated(job_id, data, event) abort
    if a:data == 0
        if index(s:added_dbs, self.db_file) < 0
            call add(s:added_dbs, self.db_file)
            execute 'cs add ' . fnameescape(s:db_file)
        else
            execute 'cs reset'
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
        if !(has('nvim') && exists('*jobwait'))
            if !g:gutentags_trace
                silent execute l:cmd
            else
                execute l:cmd
            endif
        else
            let job_dict = { 'db_file': a:tags_file, 'on_exit' : function('gutentags#cscope#command_terminated') }
            let job_cmd = [ s:runner_exe,
                        \ '-e', g:gutentags_cscope_executable,
                        \ '-p', a:proj_dir,
                        \ '-f', a:tags_file ]
            let job_id = jobstart(job_cmd, job_dict)
        endif

        let l:full_scopedb_file = fnamemodify(a:tags_file, ':p')
        call gutentags#add_progress('cscope', l:full_scopedb_file)
    else
        call gutentags#trace("(fake... not actually running)")
    endif
    call gutentags#trace("")
endfunction

" }}}

