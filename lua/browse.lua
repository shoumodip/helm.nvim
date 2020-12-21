require "helm"
-- Variables -{{{
local fn = vim.fn
local api = vim.api
local ls_cmd = 'ls -p --format=single-column --group-directories-first'

local browse_dir
local browse_prompt
-- }}}
-- Create the prompt -{{{
local function create_browse_prompt()
  browse_prompt = 'Files (' ..
  fn.resolve(fn.fnameescape(browse_dir))
  :gsub('^' .. os.getenv('HOME'), '~')
  .. '):'
end
-- }}}
-- Browser in Helm -{{{
function helm_browse()
  browse_dir = vim.loop.cwd()
  create_browse_prompt()

  helm_start({
    prompt = browse_prompt,

    matches = {
      ["/$"] = 'Define'
    },

    mappings = {
      ["<Return>"] = 'require "browse".browse_accept',
      ["<BS>"] = 'require "browse".browse_backspace'
    },

    on_enter = function(f)
      vim.cmd('edit ' .. fn.fnameescape(browse_dir .. '/' .. f))
    end,

    items = fn.systemlist(ls_cmd .. ' ' .. browse_dir)
  })
end
-- }}}
-- Accept current item -{{{
local function helm_browse_accept()
  local chosen_option

  if #helm_matched_items > 0 then
    chosen_option = fn.getline(helm_selected_line):sub(2, -1)
  else
    chosen_option = helm_match_pattern
  end

  if chosen_option:match('/$') then
    browse_dir = browse_dir .. '/' .. chosen_option:sub(1, -2)
    create_browse_prompt()
    helm_prompt = browse_prompt
    helm_match_list = fn.systemlist(ls_cmd .. ' ' .. browse_dir)

    helm_cursor_position = 1
    helm_match_pattern, helm_before_cursor, helm_after_cursor = '', '', ''

    helm_fix_match_list()
    helm_get_matches()
    helm_render()
  else
    helm_accept()
  end
end
-- }}}
-- Modified Backspace functionality in helm_browse -{{{
local function helm_browse_backspace()
  if helm_match_pattern == '' then
    browse_dir = fn.fnamemodify(browse_dir, ':h')
    create_browse_prompt()
    helm_prompt = browse_prompt
    helm_match_list = fn.systemlist(ls_cmd .. ' ' .. browse_dir)

    helm_fix_match_list()
    helm_get_matches()
    helm_render()
  else
    helm_key_backspace()
  end
end
-- }}}
-- Keybindings -{{{
api.nvim_set_keymap('n', '<Leader>.', ':lua helm_browse()<CR>',
{silent = true, noremap = true})
-- }}}
-- Return -{{{
return {
  browse_accept = helm_browse_accept,
  browse_backspace = helm_browse_backspace,
}
-- }}}
