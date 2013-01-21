" Vim Configuration File
" Description: Optimized for C/C++ development.
" Author: João Sampaio <jpmelos@jpmelos.com>

" marks the 80th column with red
set colorcolumn=80

" use C/C++ indentation
set cindent

" tabs/spaces for indentation
set tabstop=8     " tab width is 8 spaces
set softtabstop=8 " tab width is 8 spaces
set shiftwidth=8  " indent also with 8 spaces
set noexpandtab   " will not expand tabs

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
