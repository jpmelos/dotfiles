" Vim Configuration File
" Description: Optimized for C/C++ development.
" Author: João Sampaio <jpmelos@gmail.com>

" marks the 80th column with red
set colorcolumn=80

" use C/C++ indentation
set cindent

" tabs/spaces for indentation
set tabstop=4     " tab width
set softtabstop=4 " tab width
set shiftwidth=4  " indent
set expandtab

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
