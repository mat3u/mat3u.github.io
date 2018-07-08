set nocompatible

" Enable sytax coloring
syntax on

set background=dark

" Allows to change buffers when unsaved (actually don't close buffer when changed)
set hidden

" Toggle relative and absolute numbering mode
augroup numbertoggle
  autocmd!
  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
augroup END

set number relativenumber
set numberwidth=4

" Set colors for line numbers
" highlight LineNr term=bold cterm=NONE ctermfg=DarkGrey ctermbg=NONE gui=NONE guifg=DarkGrey guibg=NONE

" Don't display MODE in first line of statusline
set noshowmode

" Replace tabs with spaces
set tabstop=4 softtabstop=0 expandtab shiftwidth=2 smarttab

" Disable ~ and swap files 
" TODO: rething, it might be risky
set nobackup
set noswapfile

" Set system clipboard as default
set clipboard=unnamed

" Set <leader> and shortcuts
let mapleader = '\'

" Splits - natural splits
set splitbelow
set splitright

" Vertical line style
set fillchars=vert:│

" Set status line
function! GitBranch()
  return system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
endfunction

function! StatuslineGit()
  let l:branchname = GitBranch()
  return strlen(l:branchname) > 0?'  '.l:branchname.' ':''
endfunction

set statusline=
set statusline+=%#PmenuSel#
set statusline+=%{StatuslineGit()}
"set statusline+=%#LineNr#
set statusline+=\ %f
set statusline+=%m\
set statusline+=%=
set statusline+=%#CursorColumn#
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\[%{&fileformat}\]
set statusline+=\ %p%%
set statusline+=\ %l:%c
set statusline+=\ 

"""""" Mappings """"""

" Remap ESC
map! <leader><leader> <ESC>
map! jk <ESC>
map! kj <ESC>
map! jj <ESC>

" Fix typical missclicks
command! WQ wq
command! Wq wq
command! W w
command! Q q

" \<BS -> kill buffer, \] -> next buffer, \[ -> prev buffer
nnoremap <leader><BS> :bdelete<CR>
nnoremap <leader><leader><BS> :bdelete!<CR>
nnoremap <leader>] :bnext<CR>
nnoremap <leader>[ :bprevious<CR>

" Split - navigation C-L to left, etc
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Split - create with - (horizontal) and | (vertical)
nnoremap <C-w>- :split<CR>
nnoremap <C-w>\| :vsplit<CR>

""" Experiments
function! InsertStatuslineColor(mode)
  if a:mode == 'i'
    hi statusline guibg=magenta
  elseif a:mode == 'r'
    hi statusline guibg=blue
  else
    hi statusline guibg=red
  endif
endfunction

au InsertEnter * call InsertStatuslineColor(v:insertmode)
au InsertChange * call InsertStatuslineColor(v:insertmode)
au InsertLeave * hi statusline guibg=green
