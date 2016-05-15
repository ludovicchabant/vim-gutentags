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

let s:db_connected = 0

function! gutentags#gtags_cscope#init(project_root) abort
	let l:db_path = gutentags#get_cachefile(
				\ a:project_root, g:gutentags_gtags_dbpath )
	let l:db_file = l:db_path . '/GTAGS'

	if !isdirectory(l:db_path)
		call mkdir(l:db_path, 'p')
	endif

	let b:gutentags_files['gtags_cscope'] = l:db_file

	execute 'set cscopeprg=' . g:gutentags_gtags_cscope_executable

	" The combination of gtags-cscope, vim's cscope and global files is
	" a bit flaky. Environment variables are safer than vim passing
	" paths around and interpreting input correctly.
	let $GTAGSDBPATH = l:db_path
	let $GTAGSROOT = a:project_root

	if g:gutentags_auto_add_gtags_cscope && filereadable(l:db_file)
		set nocscopeverbose
		execute 'cs add ' . fnameescape(l:db_file)
		set cscopeverbose
		let s:db_connected = 1
	endif
endfunction

function! gutentags#gtags_cscope#command_terminated(job_id, data, event) abort
	if a:data == 0
		if !s:db_connected
			set nocscopeverbose
			execute 'cs add ' . fnameescape(self.db_file)
			set cscopeverbose
			let s:db_connected = 1
		endif
	endif
endfunction

function! gutentags#gtags_cscope#generate(proj_dir, db_file, write_mode) abort
	let l:db_path = fnamemodify(a:db_file, ':p:h')

	let l:cmd = gutentags#get_execute_cmd()
	" gtags doesn't honour GTAGSDBPATH and GTAGSROOT, so PWD and dbpath
	" have to be set

	let l:proj_options_file = a:proj_dir . '/' . g:gutentags_gtags_options_file
	let l:proj_options = ''
	if filereadable(l:proj_options_file)
		let l:lines = readfile(l:proj_options_file)
		let l:proj_options .= join(l:lines, ' ')
	endif

	let l:cmd .= ' PWD=' . a:proj_dir
	let l:cmd .= ' ' . g:gutentags_gtags_executable
	let l:cmd .= ' ' . l:proj_options
	let l:cmd .= ' --incremental '
	let l:cmd .= ' --quiet '
	let l:cmd .= ' ' . l:db_path
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
			let job_dict = { 'db_file': a:db_file }
			let job_cmd = l:cmd
			let job_id = jobstart(job_cmd, job_dict)
		endif

		let l:full_gtags_file = fnamemodify(l:db_path, ':p')
		call gutentags#add_progress('gtags_cscope', a:db_file)
	else
		call gutentags#trace("(fake... not actually running)")
	endif
	call gutentags#trace("")
endfunction

" }}}
