" Vundle
let iCanHazVundle=1
let vundle_readme=expand('~/.vim/bundle/vundle/README.md')
if !filereadable(vundle_readme) 
  echo "Installing Vundle.."
  echo ""
  silent !mkdir -p ~/.vim/bundle
  silent !git clone https://github.com/VundleVim/Vundle.vim ~/.vim/bundle/vundle
  let iCanHazVundle=0
endif
set nocompatible
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

filetype off
Plugin 'gmarik/vundle'
Plugin 'scrooloose/nerdtree'
Plugin 'Raimondi/delimitMate'
Plugin 'SirVer/ultisnips'
Plugin 'scrooloose/syntastic'
Plugin 'molokai'
Plugin 'honza/vim-snippets'
Plugin 'tpope/vim-commentary'
Plugin 'ervandew/supertab'
Plugin 'tpope/vim-surround'
filetype plugin indent on

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
set scrolloff=20

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

" Turn on syntax highlighting
syntax on

" only startup with Nerdtree if no file
function! StartUp()
  if 0 == argc()
    NERDTree
  end
endfunction
autocmd VimEnter * call StartUp()

let NERDTreeIgnore=['\~$', 'tmp', '\.git', '\.bundle', '.DS_Store', 'tags', '.swp']
let NERDTreeShowHidden=1
let g:NERDTreeDirArrows=0
map <Leader>n :NERDTreeToggle<CR>
map <Leader>fnt :NERDTreeFind<CR>

" delimitMate
let delimitMate_expand_cr = 1
let delimitMate_expand_space = 1
let delimitMate_jump_expansion = 1
let g:delimitMate_balance_matchpairs = 1

" Ultisnips
set runtimepath+=~/.vim/bundle/vim-snippets
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"
let g:UltiSnipsListSnippets="<c-l>"

" Syntastic
let g:syntastic_mode_map = { 'mode': 'active',
                            \ 'active_filetypes': ['c', 'python', 'javascript'],
                            \ 'passive_filetypes': [] }

set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_javascript_checkers = ['eslint']
let g:syntastic_c_checkers=['make', 'gcc']
let g:syntastic_c_check_header = 1

