" Encoding
set encoding=utf-8

" Whitespace
set wrap
set textwidth=80
set formatoptions=tcqrn1
set tabstop=2
set shiftwidth=2
set softtabstop=2
set expandtab
set noshiftround

" Color scheme (terminal)
set t_Co=256
set background=dark
colorscheme molokai

" Remap save
" inoremap <esc> <esc>:w<cr>
inoremap <C-s> <esc>:w<cr>
nnoremap <C-s> :w<cr>
" :imap jk <Esc>

" Numbering
set number                     " Show current line number
set relativenumber             " Show relative line numbers

" Treat all numbers as decimals
set nrformats=

" disable arrow navigation keys
inoremap  <Up>    <NOP>
inoremap  <Down>  <NOP>
inoremap  <Left>  <NOP>
inoremap  <Right> <NOP>
noremap   <Up>    <NOP>
noremap   <Down>  <NOP>
noremap   <Left>  <NOP>
noremap   <Right> <NOP>

" Leader key
let mapleader = ","

" Unhighlight search results
map <Leader><space> :nohl<cr>

" Don't scroll off the edge of the page
set scrolloff=10

" Blink cursor on error instead of beeping (grr)
set visualbell

" Better search behavior
set hlsearch
set incsearch
set ignorecase
set smartcase

" Status bar
set laststatus=2

" Move up/down editor lines
nnoremap j gj
nnoremap k gk

" Helps force plugins to load correctly when it is turned back on below
" filetype off

" TODO: Load plugins here (pathogen or vundle)

" Turn on syntax highlighting
syntax on
