" Vim Configuration File
" Description: Optimized for Python development.
" Author: João Sampaio <jpmelos@jpmelos.com>

" marks the 80th column with red
set colorcolumn=80

" configure Vim to indent Python correctly (PEP8 compliant)
let g:pyindent_open_paren = '&sw'
let g:pyindent_nested_paren = '&sw'
let g:pyindent_continue = '&sw'

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

" stops Vim from removing indentation before # comments
inoremap # X<c-h>#

" -------------------------------
" Syntastic configuration
" -------------------------------
" We don't want Syntastic do to Python checking, because python-mode is
" already doing it for us. And it's much better.
let g:syntastic_python_checkers=['']
" -------------------------------

" -------------------------------
" python-mode configuration
" -------------------------------
" Use all available linters.
let g:pymode_lint_checker = "pylint,pyflakes,pep8,mccabe"
" Don't ignore any errors.
let g:pymode_lint_ignore = ""
" Don't show error window.
let g:pymode_lint_cwindow = 0
" Don't load Rope.
let g:pymode_rope = 0
" Disable loading breakpoints.
let g:pymode_breakpoint = 0
