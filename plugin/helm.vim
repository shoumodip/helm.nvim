if exists('g:loaded_helm') | finish | endif " Prevent loading file twice

let s:save_cpo = &cpo " Save user coptions
set cpo&vim           " Reset them to defaults

lua require "menus"

let &cpo = s:save_cpo " And restore after
unlet s:save_cpo

let g:loaded_helm = 1
