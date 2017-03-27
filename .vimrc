" VIM Configuration File
" Author: João Sampaio <jpmelos@gmail.com>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" BASIC SETTINGS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" mappings default leader
let mapleader = ','

" enable filetype detection and use of plugins
filetype plugin indent on

" enable syntax highlighting
syntax on

" set UFT-8 encoding
set enc=utf-8
set fenc=utf-8
set tenc=utf-8

" disable vi compatibility
set nocompatible

" wrap lines to fit in window
set wrap

" break words intelligently
set linebreak

" do not show white chars like tabs and end-of-lines
set nolist

" highlight matching braces
set showmatch

" configure searching
set incsearch  " incremental searching
set ignorecase " ignore case when searching...
set smartcase  " unless it contais uppercase
set hls        " highlight search results

" no backup file
set nobackup

" terminal background dark, adapt colors
set background=dark

" show line numbers
set number

" allow backspacing over everything
set backspace=eol,start,indent

" define line feeds and carrige returns
set ffs=unix,dos,mac

" show details about commands (like how many chars are selected in visual
" mode)
set showcmd

set novisualbell      " don't blink
set noerrorbells      " no noise

" keeps cursor in the middle of the screen (unless you have a 2,000 lines high
" screen, in such case call me because I want to see that)
set scrolloff=999

set autoindent        " enable indentation of previous line on next
set shiftwidth=4      " tab stops are 4 spaces
set tabstop=4         " tab stops are 4 spaces
set expandtab         " tab stops become spaces

set colorcolumn=80    " highlight 80th column

" always displays file name, current line and column number
set laststatus=2

set wildmode=longest,list,full " filename auto-completion works bash-like
set wildmenu " when hits to complete full name, shows list of filenames

" Turn paste mode on and off with F8
set pastetoggle=<F8>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MAPPINGS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" navigate through display lines
nnoremap j gj
vnoremap j gj
nnoremap k gk
vnoremap k gk

" move lines in a file
nnoremap - ddp
nnoremap _ ddkkp

" clear highlight when refreshing.
nnoremap <C-L> :nohls<CR><C-L>
inoremap <C-L> <C-O>:nohls<CR>

" allows for easily disabling this functionality
noremap <F12> :let &scrolloff=999-&scrolloff<CR>

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

" uppercase current word
nnoremap <C-U> viwU<ESC>
inoremap <C-U> <ESC>viwU<ESC>ea

" allows quick editing and sourcing my .vimrc
nnoremap <leader>ev :vsplit $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>:nohls<CR>

" quickly navigate to start and end of lines
nnoremap H 0
nnoremap L $


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" STATUS LINE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set statusline=\ %f\  " file name
set statusline+=-\  " separator
set statusline+=FileType:\  " label
set statusline+=%y\  "file type
set statusline+=%m%r\  " shows modified file or read-only
set statusline+=%= " change side
set statusline+=%5l/%L\  " show current line/total lines


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AUTO COMMANDS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

augroup general_commands
    autocmd!

    " remove trailing whitespaces before saving
    autocmd BufWritePre * %s/\s\+$//e
augroup END
