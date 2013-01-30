" Vim Configuration File
" Description: Optimized for Python development.
" Author: João Sampaio <jpmelos@jpmelos.com>

" marks the 80th column with red
set colorcolumn=80

" defines Python relevant works for smart indentation
set smartindent cinwords=if,elif,else,for,while,with,try,except,finally,def,class
" stops Vim from removing indentation before # comments
inoremap # X<c-h>#

" Python-specific indetation and tab rules
set tabstop=4     " tab width is 4 spaces
set softtabstop=4 " tab width is 4 spaces
set shiftwidth=4  " indent also with 4 spaces
set expandtab     " will expand tabs into spaces

" trailing whitespaces
highlight BadWhitespace ctermbg=red guibg=red
match BadWhitespace /\s\+$/       " make trailing whitespace be flagged
au BufWritePre *,*.* :%s/\s\+$//e " deletes trailing whites when saving files

" Searches for classes and public methods.
nmap t /^    def [^_]\\|^class<CR>
