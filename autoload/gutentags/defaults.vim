" defaults.vim - default finders for Gutentags

" Get info on the project we're inside of.
function! gutentags#defaults#get_project_info(path) abort
    let l:result = {}

    for proj_info in g:gutentags_project_info
        let l:filematch = get(proj_info, 'file', '')
        let l:type = get(proj_info, 'type', '')
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

    return l:result
endfunction

function! gutentags#defaults#get_project_file_list_cmd(proj_root, proj_type) abort

    if type(g:gutentags_file_list_command) == type("")
        return gutentags#validate_cmd(g:gutentags_file_list_command)
    elseif type(g:gutentags_file_list_command) == type({})
        let l:markers = get(g:gutentags_file_list_command, 'markers', {})
        if type(l:markers) == type({})
            for [marker, file_list_cmd] in items(l:markers)
                if !empty(globpath(a:proj_root, marker, 1))
                    call gutentags#trace("Found marker matching project: ".marker.". using file list command: '".file_list_cmd."'.")
                    return gutentags#validate_cmd(file_list_cmd)
                endif
            endfor
        endif
        let l:types = get(g:gutentags_file_list_command, 'types', {})
        if !empty(l:types) && type(l:types) == type({})
            let l:file_list_cmd = get(l:types, a:proj_type, '')
            if !empty(l:file_list_cmd)
                call gutentags#trace("Found type matching project: ".l:proj_info['type'].". using file list command: '".l:file_list_cmd."'.")
                return gutentags#validate_cmd(l:file_list_cmd)
            endif
        endif
        call gutentags#trace("Using default find command '".get(g:gutentags_file_list_command, 'default', "")."'.")
        return gutentags#validate_cmd(get(g:gutentags_file_list_command, 'default', ""))
    endif
    return ""
endfunction

" Finds the first directory with a project marker by walking up from the given
" file path.
function! gutentags#defaults#get_project_root(path) abort
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

