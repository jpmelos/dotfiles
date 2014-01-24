" VIM Configuration File
" Description: Optimized for C/C++, Python and HTML/CSS development.
" Author: João Sampaio <jpmelos@gmail.com>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GENERAL SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" ----------------------------
" Activates Pathogen
" ---------------------------
" These lines need to come together first in the file for Pathogen
" to work correctly.
" ----------------------------
execute pathogen#infect()

" enable filetype detection and use of plugins
filetype plugin indent on

" enable syntax highlighting
syntax on
" ----------------------------

" set UFT-8 encoding
set enc=utf-8
set fenc=utf-8
set tenc=utf-8

" disable vi compatibility
set nocompatible

" wrap lines to window fit
set wrap
set nolist
set linebreak

" highlight matching braces
set showmatch

" keyboard mappings
" navigate through display lines
nmap j gj
nmap k gk

" configure searching
set incsearch  " incremental searching
set ignorecase " ignore case when searching...
set smartcase  " unless it contais uppercase
set hls        " highlight search results

" clear highlight when refreshing.
nnoremap <C-L> :nohls<CR><C-L>
inoremap <C-L> <C-O>:nohls<CR>

" no backup file
set nobackup

" terminal background dark, adapt colors
set background=dark

" show line numbers
set number

" allow backspacing over everything
set backspace=eol,start,indent

" filetypes (for line feeds and carrige returns)
set ffs=unix,dos,mac

set showcmd           " show incomplete commands

set novisualbell      " don't blink
set noerrorbells      " no noise

" keeps cursor in the middle of the screen (unless you have a 2,000 lines high
" screen, in such case call me because I want to see that)
set scrolloff=999
" allows for easily disabling this functionality
map <F12> :let &scrolloff=999-&scrolloff<CR>

set autoindent        " enable indentation of previous line on next

" always displays file name, current line and column number
set laststatus=2

set wildmode=longest,list,full " filename auto-completion works bash-like
set wildmenu " when hits to complete full name, shows list of filenames

" Search for selected text, forwards or backwards.
vnoremap <silent> * :<C-U>
	\let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
	\gvy/<C-R><C-R>=substitute(
	\escape(@", '/\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
	\gV:call setreg('"', old_reg, old_regtype)<CR>
vnoremap <silent> # :<C-U>
	\let old_reg=getreg('"')<Bar>let old_regtype=getregtype('"')<CR>
	\gvy?<C-R><C-R>=substitute(
	\escape(@", '?\.*$^~['), '\_s\+', '\\_s\\+', 'g')<CR><CR>
	\gV:call setreg('"', old_reg, old_regtype)<CR>

" Turn paste mode on and off with F8
set pastetoggle=<F8>

" Turn wrap lines on and off with F10
nnoremap <F10> :set wrap!<CR>
inoremap <F10> <ESC>:set wrap!<CR>i

" Configure <Space> to open folds.
nnoremap <silent> <Space> @=(foldlevel('.')?'za':"\<Space>")<CR>
vnoremap <Space> zf

" Some maps for easier tag navigation
nnoremap [q :tprevious<CR>
nnoremap ]q :tnext<CR>

" map leader to comma
let mapleader = ','
let g:mapleader = ','

" -------------------------------
" Syntastic configuration
" -------------------------------
" check files when open
let g:syntastic_check_on_open = 1
" don't check files when closing
let g:syntastic_check_on_wq = 0

" -------------------------------
" CtrlP configuration
" -------------------------------
" Use ctrl-x for file search.
let g:ctrlp_map = '<c-x>'
" Use this command for list of files to search.
let g:ctrlp_user_command = ['.git', 'cd %s && git ls']
" If don't find any list of files with command above, use first folder that
" finds a .git folder or current folder.
let g:ctrlp_working_path_mode = 'ra'
" enable looking for tags
let g:ctrlp_extensions = ['tag']
" -------------------------------

" -------------------------------
" grep.vim configuration
" -------------------------------
" Make grep case-insensitive.
let g:Grep_Default_Options = '-i --binary-files=without-match'
let g:Grep_Skip_Files = 'tags *.bak *~ *.pyc *.o *.obj *.uitest'
let g:Grep_Skip_Dirs = '.bzr .git .hg .vimprj .repo'
" -------------------------------

" -------------------------------
" Gundo configuration
" -------------------------------
" add mapping for opening it
nnoremap <F5> :GundoToggle<CR>
" open on the left side
let g:gundo_right = 0
" -------------------------------

" -------------------------------
" TagBar configuration
" -------------------------------
" add mapping for opening it
nnoremap <F6> :TagbarToggle<CR>
" close when tag selected
let g:tagbar_autoclose = 1
" focus when open
let g:tagbar_autofocus = 1
" indent by 1 space between levels
let g:tagbar_indent = 1
" -------------------------------

" -------------------------------
" Indexer configuration
" -------------------------------
" add mapping for re-indexing it
nnoremap <F7> :IndexerRebuild<CR>
inoremap <F7> <C-O>:IndexerRebuild<CR>
" -------------------------------

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" LANGUAGES SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
au BufEnter *.{c,cc,cpp,h} source ~/.vim/c.vim
au BufEnter *.{py,pyw} source ~/.vim/python.vim
au BufEnter {M,m}akefile* source ~/.vim/makefile.vim
au BufEnter *.{htm,html,shtml,php} source ~/.vim/web.vim
au BufEnter *.{css,scss} source ~/.vim/css.vim
au BufEnter *.rst source ~/.vim/rst.vim
au BufEnter *.tex source ~/.vim/tex.vim
au BufEnter *.sh source ~/.vim/sh.vim
au BufEnter *.sql source ~/.vim/sql.vim
