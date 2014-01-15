" Vim Configuration File
" Description: Optimized for Bash script development.
" Author: João Sampaio

" marks the 80th column with red
set colorcolumn=80

" tabs/spaces for indentation
set tabstop=4     " tab width
set softtabstop=4 " tab width
set shiftwidth=4  " indent
set expandtab

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
