" VIM Configuration File
" Description: Optimized for C/C++, Python and HTML/CSS development.
" Author: João Sampaio <jpmelos@jpmelos.com>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GENERAL SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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
set nohlsearch " does not highlight searches
set incsearch  " incremental searching
set ignorecase " ignore case when searching...
set smartcase  " unless it contais uppercase

" no backup file
set nobackup

" syntax highlighting
syntax on
set background=dark " terminal background dark, adapt colors

" allow backspacing over everything
set backspace=eol,start,indent

" filetypes (for line feeds and carrige returns)
set ffs=unix,dos,mac

" highlights bad whitespaces: whitespaces after then last valid character in a
" line or whitespaces in an empty line
highlight BadWhitespace ctermbg=red guibg=red

set showcmd           " show incomplete commands

set novisualbell      " don't blink
set noerrorbells      " no noise

set scrolloff=10      " minimal number of lines above and below cursor

set autoindent        " enable indentation of previous line on next

" trailing whitespaces
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files

" marks the 80th column with red
set colorcolumn=80

" always displays file name, current line and column number
set laststatus=2

filetype on            " enables filetype detection
filetype plugin on     " enables filetype specific plugins

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" LANGUAGES SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
au BufEnter *.{c,cc,cpp,h} source ~/.vim/c.vim
au BufEnter *.{py,pyw} source ~/.vim/python.vim
au BufEnter {M,m}akefile* source ~/.vim/makefile.vim
au BufEnter *.{htm,html,shtml,css,php} source ~/.vim/web.vim
