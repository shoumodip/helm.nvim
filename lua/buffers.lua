require "helm"
-- Variables -{{{
local fn = vim.fn
local api = vim.api
local buffers_list = {}
local hidden_buffers = {}
-- }}}
-- Get the list of buffers -{{{
local function get_buffers(show_hidden)
  local show_hidden = show_hidden and show_hidden or false

  local last_buffer = fn.bufnr('$')
  local current_buffer = fn.bufnr()

  buffers_list = {}
  hidden_buffers = {}

  for i = 1, last_buffer do
    if i ~= current_buffer and fn.bufloaded(i) == 1 then
      table.insert(buffers_list, '[' .. i .. '] ' .. fn.bufname(i):gsub('^$', '(No Name)'))
    elseif i ~= current_buffer and show_hidden and fn.bufname(i) ~= '' then
      table.insert(hidden_buffers, '[' .. i .. '] ' .. fn.bufname(i):gsub('^$', '(No Name)'))
    end
  end

  if fn.buflisted(current_buffer) then
    current_buffer = '[' .. current_buffer .. '] ' .. fn.bufname(current_buffer):gsub('^$', '(No Name)')

    if #buffers_list > 0 then
      table.insert(buffers_list, '# Current Buffer')
    end

    table.insert(buffers_list, current_buffer)

    if show_hidden and #hidden_buffers > 0 then
      table.insert(buffers_list, '# Hidden Buffers')
      buffers_list = table.merge(buffers_list, hidden_buffers)
    end
  end
end
-- }}}
-- Use helm to switch buffers -{{{
function helm_buffers(show_hidden)
  get_buffers(show_hidden)

  helm_start({
    prompt = 'Buffers:',

    on_enter = function(f)
      vim.cmd('buffer ' .. f:gsub('^%[', ''):gsub('%].*', ''))
    end,

    matches = {
      ['(No Name)'] = 'Macro',
      ['\\[[0-9]*\\]'] = 'Character',
    },

    items = buffers_list
  })
end
-- }}}
-- Keybindings -{{{
api.nvim_set_keymap('n', '<Leader>,',  ':lua helm_buffers()<CR>',
{ noremap = true, silent = true })

api.nvim_set_keymap('n', '<Leader><',  ':lua helm_buffers(true)<CR>',
{ noremap = true, silent = true })

api.nvim_set_keymap('n', '<Leader>bb', ':lua helm_buffers()<CR>',
{ noremap = true, silent = true })

api.nvim_set_keymap('n', '<Leader>bB', ':lua helm_buffers(true)<CR>',
{ noremap = true, silent = true })
-- }}}
