" VIM Configuration File
" Author: João Sampaio <jpmelos@gmail.com>

"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" VUNDLE SETUP
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set nocompatible              " required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

" let Vundle manage Vundle, this is required
Plugin 'gmarik/Vundle.vim'

" Add all your plugins here (note older versions of Vundle used Bundle
" instead of Plugin)
Plugin 'tmhedberg/SimpylFold'
Plugin 'Valloric/YouCompleteMe'
Plugin 'scrooloose/nerdtree'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'embear/vim-localvimrc'
Plugin 'tpope/vim-fugitive'
Plugin 'ap/vim-buftabline'

" All of your Plugins must be added before the following line
call vundle#end()            " required


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" COLORS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" popup menu with clearer colors
highlight Pmenu ctermfg=Black ctermbg=White
highlight PmenuSel ctermfg=Black ctermbg=LightGray

" enable syntax highlighting
syntax on


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" BASIC SETTINGS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" enable filetype detection and use of plugins
filetype plugin indent on

" mappings default leader
let mapleader = ','

" set UFT-8 encoding
set encoding=utf-8
set fileencoding=utf-8
set termencoding=utf-8

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

" terminal background dark, adapt colors
set background=dark

" show line numbers
set number

" allow backspacing over everything
set backspace=eol,start,indent

" define line feeds and carrige returns
set fileformats=unix,dos,mac

" show details about commands (like how many chars are selected in visual
" mode)
set showcmd

set novisualbell      " don't blink
set noerrorbells      " no noise

" keeps cursor in the middle of the screen (unless you have a 2,000 lines high
" screen, in such case call me because I want to see that)
set scrolloff=999

set autoindent        " enable indentation of previous line on next
set tabstop=4         " tab stops are 4 spaces
set softtabstop=4     " tab stops are 4 spaces
set shiftwidth=4      " tab stops are 4 spaces
set expandtab         " tab stops become spaces

" always displays file name, current line and column number
set laststatus=2

set wildmode=longest,list,full " filename auto-completion works bash-like
set wildmenu " when hits to complete full name, shows list of filenames

" turn paste mode on and off with F8
set pastetoggle=<F8>

" new splits goes to the right and below
set splitright
set splitbelow

" ignore __pycache__ and .pyc files
set wildignore+=*/__pycache__/*,*.pyc,*/.git/*

" look for tags in parent directories
set tags=./tags;,tags;

" save temporary files to a default directory
set backupdir=~/.vim/backup//
set directory=~/.vim/swap//
set undodir=~/.vim/undo//

" autoclose YouCompleteMe helper window
let g:ycm_autoclose_preview_window_after_completion=1

" allow hidden buffers
set hidden


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" MAPPINGS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" navigate through display lines
nnoremap j gj
vnoremap j gj
nnoremap k gk
vnoremap k gk

" navigate through splits
nnoremap <C-J> <C-W>j
nnoremap <C-K> <C-W>k
nnoremap <C-L> <C-W>l
nnoremap <C-H> <C-W>h

" move lines in a file
nnoremap - ddp
nnoremap _ ddkkp

" quickly navigate to start and end of lines
nnoremap H 0
nnoremap L $

" clear highlight when refreshing.
nnoremap <C-C> :nohls<CR><C-L>
inoremap <C-C> <C-O>:nohls<CR>

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

" fast fold toggle
nnoremap <Space> za

" uppercase current word
nnoremap <C-U> viwU<ESC>
inoremap <C-U> <ESC>viwU<ESC>ea

" allows quick editing and sourcing my .vimrc
nnoremap <leader>ev :vsplit $MYVIMRC<CR>
nnoremap <leader>sv :source $MYVIMRC<CR>:nohls<CR>

" toggle search
nnoremap <F5> /\v

" close buffers
nnoremap <F4> :bw<CR>

" navigate through "virtual tabs" by vim-buftabline
nnoremap <C-N> :bprev<CR>
nnoremap <C-M> :bnext<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" STATUS LINE
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set statusline=\ %f\  " file name
set statusline+=-\  " separator
set statusline+=FileType:\  " label
set statusline+=%y\  "file type
set statusline+=%m%r\  " shows modified file or read-only
set statusline+=%= " change side
set statusline+=%3c,%5l/%L\  " show current column, current line/total lines


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AUTO COMMANDS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

augroup general_commands
    autocmd!

    " remove trailing whitespaces before saving
    autocmd BufWritePre * %s/\s\+$//e

    " for full-stack development
    au BufNewFile,BufRead *.html,*.css,*.js,*.jsx set tabstop=2 softtabstop=2 shiftwidth=2

augroup END


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NERDTREE CONFIGURATION
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

noremap <F9> :NERDTreeToggle<CR><C-W>=

augroup nerdtree
    autocmd!

    " Automatically open NERDTree if Vim opens with no file
    autocmd StdinReadPre * let s:std_in=1
    autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

augroup END


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TOGGLE ALL FOLDS
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

function! ToggleAllFolds()
    if !exists("b:all_folds_collapsed")
        let b:all_folds_collapsed = 1
    endif

    if b:all_folds_collapsed
        execute ":normal! zR"
        let b:all_folds_collapsed = 0
    else
        execute ":normal! zM"
        let b:all_folds_collapsed = 1
    endif
endfunction

nnoremap <Leader><Space> :call ToggleAllFolds()<CR>


"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" GREP OPERATOR
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

nnoremap <leader>g :set operatorfunc=<SID>GrepOperator<cr>g@
vnoremap <leader>g :<c-u>call <SID>GrepOperator(visualmode())<cr>

function! s:GrepOperator(type)
    let saved_unnamed_register = @@

    if a:type ==# 'v'
        normal! `<v`>y
    elseif a:type ==# 'char'
        normal! `[v`]y
    else
        return
    endif

    silent execute "grep! --exclude-dir=.git --binary-files=without-match -R " . shellescape(@@) . " ."
	redraw!
    copen

    let @@ = saved_unnamed_register
endfunction

nnoremap <Leader>n :cnext<CR>
nnoremap <Leader>b :cprevious<CR>
