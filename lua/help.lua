require "helm"
-- Variables -{{{
local api = vim.api
local fn = vim.fn
-- }}}
-- Describe a function -{{{
function helm_describe_function()
  helm_start({
    prompt = 'Describe function:',

    on_enter = function(f)
      vim.cmd('help ' .. f)
    end,

    items = table.map(fn.getcompletion('', 'function'),
    function(f)
      if f:sub(-1, -1) == ')' then
        return f:sub(1, -3)
      else
        return f:sub(1, -2)
      end
    end)
  })
end
-- }}}
-- Describe a variable -{{{
function helm_describe_variable()
  helm_start({
    prompt = 'Describe variable:',

    on_enter = function(v)
      vim.cmd("help " .. v)
    end,

    items = table.merge(
    fn.getcompletion('', 'var'),

    table.map(fn.getcompletion('', 'option'),
    function(v)
      return "'" .. v .. "'"
    end
    ))
  })
end
-- }}}
-- Keybindings -{{{
api.nvim_set_keymap('n', '<Leader>hf', ':lua helm_describe_function()<CR>',
{ noremap = true, silent = true })

api.nvim_set_keymap('n', '<Leader>hv', ':lua helm_describe_variable()<CR>',
{ noremap = true, silent = true })
-- }}}
