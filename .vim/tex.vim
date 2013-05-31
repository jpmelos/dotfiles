" Vim Configuration File
" Description: Optimized for LaTeX writing.
" Author: João Sampaio <jpmelos@gmail.com>

" marks the 80th column with red
set colorcolumn=80

" tabs/spaces for indentation
set tabstop=4     " tab width is 4 spaces
set softtabstop=4 " tab width is 4 spaces
set shiftwidth=4  " indent also with 4 spaces
set expandtab     " will expand tabs

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
