require "helm"
-- Variables -{{{
local api = vim.api
local fn = vim.fn
-- }}}
-- Set the filetype -{{{
function helm_filetype()
  helm_start({
    prompt = 'Filetype:',

    on_enter = function(f)
      vim.cmd('set filetype=' .. f)
    end,

    items = fn.getcompletion('', 'filetype'),
  })
end
-- }}}
-- Run commands -{{{
function helm_command()
  helm_start({
    prompt = 'Command:',

    on_enter = function(c)
      fn.feedkeys(':' .. c, 'n')
    end,

    items = fn.getcompletion('', 'command'),
  })
end
-- }}}
-- Keybindings -{{{
api.nvim_set_keymap('n', '<Leader>ft', ':lua helm_filetype()<CR>',
{ noremap = true, silent = true })

api.nvim_set_keymap('n', '<Leader>;',  ':lua helm_command()<CR>',
{ noremap = true, silent = true })
-- }}}
