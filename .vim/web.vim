" Vim Configuration File
" Description: Optimized for Web development.
" Author: João Sampaio <jpmelos@jpmelos.com>

" marks the 80th column with red
set colorcolumn=80

" tabs/spaces for indentation
set tabstop=2     " tab width is 8 spaces
set softtabstop=2 " tab width is 8 spaces
set shiftwidth=2  " indent also with 8 spaces
set expandtab     " will expand tabs into spaces

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
