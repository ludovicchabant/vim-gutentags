" gtags_cscope module for Gutentags

if !has('cscope')
	throw "Can't enable the gtags-cscope module for Gutentags, this Vim has ".
				\ "no support for cscope files."
endif

" Global Options {{{

if !exists('g:gutentags_gtags_executable')
	let g:gutentags_gtags_executable = 'gtags'
endif

if !exists('g:gutentags_gtags_dbpath')
	let g:gutentags_gtags_dbpath = ''
endif

if !exists('g:gutentags_gtags_options_file')
	let g:gutentags_gtags_options_file = '.gutgtags'
endif

if !exists('g:gutentags_gtags_cscope_executable')
	let g:gutentags_gtags_cscope_executable = 'gtags-cscope'
endif

if !exists('g:gutentags_auto_add_gtags_cscope')
	let g:gutentags_auto_add_gtags_cscope = 1
endif

" }}}

" Gutentags Module Interface {{{

let s:added_db_files = {}
let s:job_db_files = []

function! s:add_db(db_file) abort
	if filereadable(a:db_file)
		call gutentags#trace(
					\"Adding cscope DB file: " . a:db_file)
		set nocscopeverbose
		execute 'cs add ' . fnameescape(a:db_file)
		set cscopeverbose
		let s:added_db_files[a:db_file] = 1
	else
		call gutentags#trace(
					\"Not adding cscope DB file because it doesn't " .
					\"exist yet: " . a:db_file)
	endif
endfunction

function! gutentags#gtags_cscope#init(project_root) abort
	let l:db_path = gutentags#get_cachefile(
				\ a:project_root, g:gutentags_gtags_dbpath )
	let l:db_path = gutentags#stripslash(l:db_path)
	let l:db_file = l:db_path . '/GTAGS'
	let l:db_file = gutentags#normalizepath(l:db_file)

	if !isdirectory(l:db_path)
		call mkdir(l:db_path, 'p')
	endif

	let b:gutentags_files['gtags_cscope'] = l:db_file

	execute 'set cscopeprg=' . fnameescape(g:gutentags_gtags_cscope_executable)

	" The combination of gtags-cscope, vim's cscope and global files is
	" a bit flaky. Environment variables are safer than vim passing
	" paths around and interpreting input correctly.
	let $GTAGSDBPATH = l:db_path
	let $GTAGSROOT = a:project_root

	if g:gutentags_auto_add_gtags_cscope && !has_key(s:added_db_files, l:db_file)
		let s:added_db_files[l:db_file] = 0
		call s:add_db(l:db_file)
	endif
endfunction

function! gutentags#gtags_cscope#on_job_out(job, data) abort
	call gutentags#trace(a:data)
endfunction

function! gutentags#gtags_cscope#on_job_exit(job, exit_val) abort
	if a:exit_val != 0
		echom "gutentags: gtags-cscope job failed :("
		return
	endif
	if g:gutentags_auto_add_gtags_cscope
		let l:idx = 0
		let l:db_file = ''
		for item in s:job_db_files
			if item[0] == a:job
				let l:db_file = item[1]
				break
			endif
			let l:idx += 1
		endfor
		if l:db_file != ''
			call s:add_db(l:db_file)
			call remove(s:job_db_files, l:idx)
		endif
	endif
endfunction

function! s:get_unix_cmd(for_job, proj_options, db_path) abort
	" Vim's `job_start` gets confused with quoted arguments on Unix,
	" prefers lists.
	if a:for_job
		let l:cmd = [g:gutentags_gtags_executable] + a:proj_options
		let l:cmd += ['--incremental', a:db_path]
		return l:cmd
	else
		let l:cmd = gutentags#get_execute_cmd()
		let l:cmd .= '"' . g:gutentags_gtags_executable . '"'
		let l:cmd .= ' ' . join(a:proj_options, ' ')
		let l:cmd .= ' --incremental '
		let l:cmd .= ' "' . a:db_path . '" '
		let l:cmd .= gutentags#get_execute_cmd_suffix()
		return l:cmd
	endif
endfunction

function! s:get_win32_cmd(for_job, proj_options, db_path) abort
	" Win32 prefers strings either way.
	let l:cmd = ''
	if !a:for_job
		let l:cmd = gutentags#get_execute_cmd()
	endif
	let l:cmd .= '"' . g:gutentags_gtags_executable . '"'
	let l:cmd .= ' ' . join(a:proj_options, ' ')
	let l:cmd .= ' --incremental '
	let l:cmd .= ' "' . a:db_path . '"'
	if !a:for_job
		let l:cmd .= ' '
		let l:cmd .= gutentags#get_execute_cmd_suffix()
	endif
	return l:cmd
endfunction

function! gutentags#gtags_cscope#generate(proj_dir, db_file, write_mode) abort
	" gtags doesn't honour GTAGSDBPATH and GTAGSROOT, so PWD and dbpath
	" have to be set
	let l:db_path = fnamemodify(a:db_file, ':p:h')

	let l:proj_options_file = a:proj_dir . '/' . g:gutentags_gtags_options_file
	let l:proj_options = []
	if filereadable(l:proj_options_file)
		let l:proj_options = readfile(l:proj_options_file)
	endif

	let l:use_jobs = has('job')
	if has('win32')
		let l:cmd = s:get_win32_cmd(l:use_jobs, l:proj_options, l:db_path)
	else
		let l:cmd = s:get_unix_cmd(l:use_jobs, l:proj_options, l:db_path)
	endif

	call gutentags#trace("Running: " . string(l:cmd))
	call gutentags#trace("In:      " . getcwd())
	if !g:gutentags_fake
		if l:use_jobs
			let l:job_opts = {
						\'exit_cb': 'gutentags#gtags_cscope#on_job_exit',
						\'out_cb': 'gutentags#gtags_cscope#on_job_out',
						\'err_cb': 'gutentags#gtags_cscope#on_job_out'
						\}
			let l:job = job_start(l:cmd, job_opts)
			call add(s:job_db_files, [l:job, a:db_file])
		else
			if !g:gutentags_trace
				silent execute l:cmd
			else
				execute l:cmd
			endif
			if g:gutentags_auto_add_gtags_cscope
				call s:add_db(a:db_file)
			endif
		endif

		call gutentags#add_progress('gtags_cscope', l:db_path)
	else
		call gutentags#trace("(fake... not actually running)")
	endif
	call gutentags#trace("")
endfunction

" }}}
