" Vim Configuration File
" Description: Optimized for Makefile development.
" Author: João Sampaio <jpmelos@jpmelos.com>

" marks the 80th column with red
set colorcolumn=80

set noexpandtab " will not expand tabs

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files
