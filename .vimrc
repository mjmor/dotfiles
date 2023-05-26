set nocompatible              " be iMproved, required
filetype off                  " required

filetype plugin indent on    " required

" Let me use the mouse
set mouse=a
" Set a colorcolumn at 80th char
set cc=80

" Set tab widths and expand tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set encoding=utf-8

" Filetype specific settings
" *.java files
autocmd FileType java setlocal shiftwidth=2 tabstop=2 softtabstop=2 expandtab

" *.html files
autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2 expandtab

" *.html files
autocmd FileType javascript setlocal shiftwidth=2 tabstop=2 softtabstop=2 expandtab

" Required for nerdcommenter and file dependent scripts
filetype plugin on

let mapleader = ','
syntax on

" save and restore folds when a file is closed and re-opened
autocmd BufWinLeave *.* mkview
autocmd BufWinEnter *.* silent loadview
autocmd BufWinEnter *.* set cc=80

" when entering new buffers, set a color column at 80
autocmd BufEnter set cc=80

" Fugitive mapping
nmap <leader>gs :Gstatus<cr>
nmap <leader>gc :Gcommit<cr>
nmap <leader>ga :Gwrite<cr>
nmap <leader>gl :Glog<cr>
nmap <leader>gd :Gdiff<cr>
nmap <leader>gp :Git push<cr>

" NerdTree mapping
map <C-n> :NERDTreeToggle<CR>

" for autocompletion, disbale search of included files
set complete-=i
let g:pymode_rope_lookup_project = 0
" autoclose pydoc when leaving insert
autocmd InsertLeave * if pumvisible() == 0|pclose|endif

" Turn off auto comment
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

""""""""""" SYNTASTIC PYTHON SETTINGS """""""""""""""
let g:syntastic_python_checkers = ['pyflakes', 'python', 'pylint']

"""""""""""""""""""""""""""""""""""""""""""

""""""""""" PYMODE SETTINGS """""""""""""""
" set pyflakes to use python3 syntax
let g:pymode_python = 'python3'
" check EVERY time I save
let g:pymode_lint_unmodified = 1
" Ignore warning about TODOs, and catching to broad of exception
" Exception warning
let g:pymode_lint_ignore = "W0511,R0911,F0401,W0633,R0914,C0302,E124,F0002"
" set my lint checkers
" removed pylint because bogus stargs error
let g:pymode_lint_checkers = ['pylint', 'pep8']
" set mccabe complexity maximum compl.
let g:pymode_lint_options_mccabe = { 'complexity': 14 }

"""""""""""""""""""""""""""""""""""""""""""

""""""""""" SYNTASTIC SETTINGS """""""""""""""
" don't check syntac on python files, use python-mode for that
let g:syntastic_mode_map = {
    \ "mode": "active",
    \ "active_filetypes": [],
    \ "passive_filetypes": ["python"] }

"""""""""""""""""""""""""""""""""""""""""""
""""""""""" AUTOPAIR SETTINGS """""""""""""""
let g:AutoPairsShortcutFastWrap = '<C-l>'

" Popup colorscheme
hi Pmenu ctermbg=0
hi Pmenu ctermfg=15

" if i scroll off screen, leave 3 lines around my cursor
" (so it doesnt sit at the bottom)
set scrolloff=3
set autoindent
set showmode
set cursorline
" shows cmd typed in bottom right
set showcmd


" Make backspace work like normal
set backspace=indent,eol,start

" show relative numbers
set relativenumber

function! NumberToggle()
    set number!
    set relativenumber!
endfunc
" set <C-l> to toggle relative and non relative
nnoremap <C-l> :call NumberToggle()<cr>

" APPEARANCE
" for vim-airline
set laststatus=2
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#branch#enabled = 1
let g:airline_theme = 'term'
set background=dark

" windows
set splitbelow
set splitright


" FUNCTIONALITY
" stop me from using arrow keys
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

"Remove all trailing whitespace by pressing F5
nnoremap <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar><CR>

" ignore case ignores case when typin in lower case search
set ignorecase
" smart case will match only if i write an uppercase letter
set smartcase
set gdefault
set incsearch
set showmatch
set hlsearch
" set // to search selected text
vnoremap // y/<C-R>"<CR>"
" set ,<space> to :noh
nnoremap <leader><space> :noh<cr>

" jump commands
function! GotoJump()
    jumps
    let j = input("Please select your jump: ")
    if j != ''
        let pattern = '\v\c^\+'
        if j =~ pattern
            let j = substitute(j, pattern, '', 'g')
            execute "normal " . j . "\<c-i>"
        else
            execute "normal " . j . "\<c-o>"
        endif
    endif
endfunction

nmap <Leader>j :call GotoJump()<CR>

" set up buffer commands
set hidden
" To open a new empty buffer
" This replaces :tabnew which I used to bind to this mapping
nmap <leader>T :enew<cr>
" Move to the next buffer
nmap <leader>l :bnext<CR>
" Move to the previous buffer
nmap <leader>h :bprevious<CR>
" Close the current buffer and move to the previous one
" This replicates the idea of closing a tab
nmap <leader>bq :bp <BAR> bd #<CR>
" Show all open buffers and their status
nmap <leader>bl :ls<CR>
