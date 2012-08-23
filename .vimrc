" VIM Configuration File
" Description: Optimized for C/C++ and Python development.
" Author: João P. Sampaio <jpmelos@jpmelos.com>
" Based on: http://amix.dk/vim/vimrc.html
"           http://github.com/murilasso
"           http://gergap.wordpress.com/2009/05/29/minimal-vimrc-for-cc-developers/
"           http://phuzz.org/vimrc.html
"           http://blog.ffelix.eti.br/aplicativos/arquivo-vimrc-otimizado/
"           Plus some other changes here and there I pick as I go...

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
set linebreak
set nolist

" highlight matching braces
set showmatch

" keyboard mappings
" save file with <F2>
nmap <F2> :w<CR>
imap <F2> <ESC>:w<CR>i
" navigate through display lines
nmap j gj
nmap k gk

" configure searching
set nohlsearch " does not highlight searches
set incsearch  " incremental searching
set ignorecase " ignore case when searching
set smartcase  " unless it contais uppercase

" no backup file
set nobackup

" syntax hilighting
syntax on
set background=dark " terminal background dark, adapt colors

" allow backspacing over everything
set backspace=eol,start,indent

" filetypes (for line feeds and carrige returns)
set ffs=unix,dos,mac

" highlights bad whitespaces: whitespaces after then last valid character in a line
" or whitespaces in an empty line
highlight BadWhitespace ctermbg=red guibg=red

" fold settings
set foldmethod=indent " fold based on indent
set foldnestmax=3     " deepest fold is 3 levels
set nofoldenable      " no fold by default

set showcmd           " show incomplete commands
set autochdir         " automatically cd into the directory the file is
set novisualbell      " don't blink
set noerrorbells      " no noise
set scrolloff=10      " minimal number of lines above and below cursor

set tabstop=8         " tab width is 8 spaces
set softtabstop=8     " tab width is 8 spaces
set shiftwidth=8      " indent also with 8 spaces
set noexpandtab       " will not expand tabs

set autoindent        " enable indentation of previous line on next

" make trailing whitespace be flagged
match BadWhitespace /\s\+$/

" marks the 80th column with red
set colorcolumn=80

" always displays file name, current line and column number
set laststatus=2

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" C SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" use C/C++ indentation
au BufRead,BufNewFile *.c,*.cc,*.cpp,*.h set cindent

" set intelligent comments
au BufRead,BufNewFile *.c,*.cc,*.cpp,*.h set comments=sl:/*,mb:\ *,elx:\ */

" automatically deletes trailing whitespaces before saving C/C++ files
au BufWritePre *.c,*.cc,*.cpp,*.h :%s/\s\+$//e

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" PYTHON SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" defines Python relevant works for smart indentation
au BufRead,BufNewFile *.py,*.pyw set smartindent cinwords=if,elif,else,for,while,with,try,except,finally,def,class

" automatically deletes trailing whitespaces before saving Python files
au BufWritePre *.py,*.pyw :%s/\s\+$//e

" Python-specific indetation and tab rules
au BufRead,BufNewFile *.py,*.pyw set tabstop=4         " tab width is 4 spaces
au BufRead,BufNewFile *.py,*.pyw set softtabstop=4     " tab width is 4 spaces
au BufRead,BufNewFile *.py,*.pyw set shiftwidth=4      " indent also with 4 spaces
au BufRead,BufNewFile *.py,*.pyw set expandtab         " will expand tabs

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MAKEFILE SECTION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" will not expand tabs when on a Makefile file
au BufRead,BufNewFile Makefile* set noexpandtab

" automatically deletes trailing whitespaces before saving Makefile files
au BufWritePre Makefile* :%s/\s\+$//e
