-- Custom modules -{{{
require "tables"
-- }}}
-- Helper variables -{{{
local api = vim.api
local fn = vim.fn
-- }}}
-- Variables -{{{
local render_text = {} -- The list of lines to be helm_rendered
local on_enter -- The function to execute on acceptance of a value
local guicursor_save -- Backup for the cursor settings
local color_matches = {}

helm_match_buffer = 0
helm_match_window = 0
helm_prompt_buffer = 0
helm_prompt_window = 0
helm_window_height = 15
helm_prompt = ''
helm_default_prompt = 'Match:'
helm_before_cursor, helm_after_cursor = '', ''
helm_cursor_position = helm_before_cursor:len() + 1
helm_match_pattern = helm_before_cursor .. helm_after_cursor
helm_selected_line = 1
helm_match_list = {}
helm_matched_items = {}
-- }}}
-- The keybindings -{{{
helm_mappings = {
  ["<Right>"] = 'helm_move_cursor_right',
  ["<Left>"] = 'helm_move_cursor_left',
  ["<C-f>"] = 'helm_move_cursor_right',
  ["<C-b>"] = 'helm_move_cursor_left',

  ["<C-a>"] = 'helm_move_cursor_begin',
  ["<C-e>"] = 'helm_move_cursor_end',

  ["<Esc>"] = 'helm_exit',
  ["<Return>"] = 'helm_accept',
  ["<BS>"] = 'helm_key_backspace',
  ["<Del>"] = 'helm_key_delete',

  ["<Down>"] = 'helm_next_item',
  ["<Up>"] = 'helm_prev_item',
  ["<C-n>"] = 'helm_next_item',
  ["<C-p>"] = 'helm_prev_item',

  ["<A-n>"] = 'helm_goto_next_region',
  ["<A-p>"] = 'helm_goto_prev_region',
}
-- }}}
-- Window settings -{{{
local function win_settings(win_handle)
  api.nvim_win_set_option(win_handle, 'winhl', 'Normal:HelmWindow')
  api.nvim_win_set_option(win_handle, 'wrap', false)
  api.nvim_win_set_option(win_handle, 'conceallevel', 2)
  api.nvim_win_set_option(win_handle, 'concealcursor', 'nvic')
  api.nvim_win_set_option(win_handle, 'scrolloff', math.floor((helm_window_height - 1) / 2) - 1)

  return ''
end
-- }}}
-- Open the helm window -{{{
local function helm_open_window()
  helm_match_buffer = api.nvim_create_buf(false, true) -- Create new empty helm_match_buffer
  helm_prompt_buffer = api.nvim_create_buf(false, true) -- Create new empty helm_match_buffer

  api.nvim_buf_set_option(helm_match_buffer, 'bufhidden', 'wipe') -- It is temporary
  api.nvim_buf_set_option(helm_prompt_buffer, 'bufhidden', 'wipe') -- It is temporary

  local win_options = {
    style = "minimal", -- Disable most options
    relative = "editor", -- Use the entire Neovim helm_match_window as the anchor
    width = vim.o.columns, -- Make it as wide as the Neovim helm_match_window
    height = helm_window_height - 1,

    -- By default, the anchor is positioned to the North-West.
    row = vim.o.lines - helm_window_height + 1, -- The starting row
    col = 0
  }

  -- And finally create it with helm_match_buffer attached
  helm_match_window = api.nvim_open_win(helm_match_buffer, true, win_options)
  win_settings(helm_match_window)

  guicursor_save = vim.o.guicursor
  vim.o.guicursor = 'a:InvisibleCursor'
  vim.cmd('syntax region HelmRegion concealends matchgroup=bTag start="^#" end="$"')

  win_options["height"] = 1
  win_options["row"] = vim.o.lines - helm_window_height - 1

  helm_prompt_window = api.nvim_open_win(helm_prompt_buffer, false, win_options)
  win_settings(helm_prompt_window)

  helm_matched_items = {}
  helm_before_cursor, helm_after_cursor = '', ''
  helm_match_pattern = helm_before_cursor .. helm_after_cursor
  helm_cursor_position = helm_before_cursor:len() + 1
  helm_selected_line = 1

  return ''
end
-- }}}
-- Exit helm -{{{
function helm_exit()
  api.nvim_buf_delete(helm_match_buffer, {})
  api.nvim_buf_delete(helm_prompt_buffer, {})
  vim.o.guicursor = guicursor_save

  return ''
end
-- }}}
-- Accept the selected item -{{{
function helm_accept()
  local chosen_option

  if #helm_matched_items > 0 then
    chosen_option = fn.getline(helm_selected_line):sub(2, -1)
  else
    chosen_option = helm_match_pattern
  end

  helm_exit()
  on_enter(chosen_option)

  return ''
end
-- }}}
-- Get the matching items -{{{
function helm_get_matches()

  -- Fuzzy matching with fixed anchors
  local helm_match_pattern = helm_match_pattern:lower()
  :gsub('.', '%1.*')
  :gsub('^%^%.%*', '^ ')
  :gsub('%.%*%$%.%*$', '$')
  :gsub('%.%.%*', '%%.')
  :gsub('%[', '%%%[')
  :gsub('%]', '%%%]')
  :gsub('%(', '%%%(')
  :gsub('%)', '%%%)')

  helm_matched_items = {}

  fn.clearmatches()
  for regex, group in pairs(color_matches) do
    fn.matchadd(group ,'^\\(# \\)\\@!.*' .. regex)
  end

  local i = 1
  local j = 1

  while i < #helm_match_list do
    s = helm_match_list[i]

    if s:match('^# .*') then

      table.insert(helm_matched_items, s)
      j = j + 1
    elseif s == '' then

      if helm_match_list[i - 1] ~= nil and helm_match_list[i - 1]:match('^#. *') then
        table.remove(helm_matched_items, s - 1)
        j = j - 1
      else
        table.insert(helm_matched_items, s)
        j = j + 1
      end

    elseif s:lower():match(helm_match_pattern) then

      local helm_match_pattern = helm_before_cursor .. helm_after_cursor
      helm_match_pattern = helm_match_pattern
      :gsub('%$$', '')
      :gsub('^%^', '')
      :gsub('%s', '')

      local hl_end = 2

      if helm_match_pattern:len() > 0 then
        for c = 1, helm_match_pattern:len() do
          hl_char = helm_match_pattern:sub(c, c):lower()
          hl_end, _ = s:lower():find(hl_char, hl_end, true)

          fn.matchaddpos('HelmMatch', {{j, hl_end}})

          hl_end = hl_end + 1
        end
      end

      table.insert(helm_matched_items, s)
      j = j + 1
    end

    i = i + 1
  end

  if #helm_matched_items > 1 and helm_matched_items[1] == '' then
    helm_selected_line = 2
  elseif #helm_matched_items == 1 and helm_matched_items[1] == '' then
    helm_matched_items = {}
  else
    helm_selected_line = 1
  end

  return ''
end
-- }}}
-- Render the colors -{{{
local function helm_render_colors()

  fn.win_gotoid(helm_prompt_window) -- Focus the prompt window

  -- Match the prompt
  fn.clearmatches()
  fn.matchadd('HelmPrompt', '\\%1l^.*\\%' .. helm_prompt:len() + 2 .. 'v')
  fn.matchadd('HelmCursor',
  '\\%1l\\%' .. helm_cursor_position + helm_prompt:len() + 2 .. 'v')
  fn.win_gotoid(helm_match_window)

  return ''
end
-- }}}
-- Render helm -{{{
function helm_render()
  helm_match_pattern = helm_before_cursor .. helm_after_cursor
  render_text = {}
  helm_get_matches()

  if helm_matched_items ~= nil then
    table.merge(render_text, helm_matched_items)
  end

  api.nvim_buf_set_lines(helm_prompt_buffer, 0, -1, false, {' ' .. helm_prompt .. ' ' .. helm_match_pattern})
  api.nvim_buf_set_lines(helm_match_buffer, 0, -1, false, render_text)
  helm_render_colors()

  if #helm_matched_items > 0 then
    if helm_matched_items[helm_selected_line]:sub(1, 3):match('# .*') then
      helm_selected_line = helm_selected_line + 1
    end

    api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
    api.nvim_win_set_option(helm_match_window, 'cursorline', true)
  else
    api.nvim_win_set_option(helm_match_window, 'cursorline', false)
  end

  return ''
end
-- }}}
-- Generate the keybindings -{{{
function helm_generate_mappings(table)
  if table == nil then
    for key = 32,126 do
      local keyname = fn.nr2char(key)
      api.nvim_buf_set_keymap(helm_match_buffer, 'n', keyname,
      ':lua helm_insert_char("' .. keyname:gsub('"', '\\"') .. '")<CR>',
      {noremap = true, silent = true, nowait = true})
    end
  end

  table = table and table or helm_mappings

  for key, action in pairs(table) do
    api.nvim_buf_set_keymap(helm_match_buffer, 'n', key,
    ':lua ' .. action .. '()<CR>',
    {noremap = true, silent = true, nowait = true})
  end

  return ''
end
-- }}}
-- Decrement the cursor position if possible -{{{
function helm_decrement_cursor()
  if helm_cursor_position > 1 then
    helm_cursor_position = helm_cursor_position - 1
  end

  return ''
end
-- }}}
-- Increment the cursor position if possible -{{{
function helm_increment_cursor()
  if helm_cursor_position <= helm_match_pattern:len() then
    helm_cursor_position = helm_cursor_position + 1
  end

  return ''
end
-- }}}
-- Backspace key in helm -{{{
function helm_key_backspace()
  if helm_before_cursor:len() > 0 then
    helm_before_cursor = helm_before_cursor:sub(1, -2)
    helm_decrement_cursor()
    helm_render()
  end

  return ''
end
-- }}}
-- Delete key in helm -{{{
function helm_key_delete()
  if helm_after_cursor:len() > 0 then
    helm_after_cursor = helm_after_cursor:sub(2, -1)
    helm_render()
  end

  return ''
end
-- }}}
-- Move the cursor left -{{{
function helm_move_cursor_left()
  helm_after_cursor = helm_before_cursor:sub(-1, -1) .. helm_after_cursor
  helm_before_cursor = helm_before_cursor:sub(1, -2)
  helm_decrement_cursor()
  helm_render_colors()

  return ''
end
-- }}}
-- Move the cursor right -{{{
function helm_move_cursor_right()
  helm_increment_cursor()
  helm_before_cursor = helm_before_cursor .. helm_after_cursor:sub(1, 1)
  helm_after_cursor = helm_after_cursor:sub(2, -1)
  helm_render_colors()

  return ''
end
-- }}}
-- Move cursor to the beginning of the match pattern -{{{
function helm_move_cursor_begin()
  helm_cursor_position = 1
  helm_after_cursor = helm_before_cursor .. helm_after_cursor
  helm_before_cursor = ''
  helm_render_colors()

  return ''
end
-- }}}
-- Move cursor to the end of the match pattern -{{{
function helm_move_cursor_end()
  helm_cursor_position = helm_match_pattern:len() + 1
  helm_before_cursor = helm_before_cursor .. helm_after_cursor
  helm_after_cursor = ''
  helm_render_colors()

  return ''
end
-- }}}
-- Select the next item -{{{
function helm_next_item()
  if #helm_matched_items > 1 then
    if helm_selected_line < #helm_matched_items then

      helm_selected_line = helm_selected_line + 1

      if helm_matched_items[helm_selected_line] == '' then
        if helm_selected_line < fn.line('$') then
          helm_selected_line = helm_selected_line + 1
        end
      end

      if helm_matched_items[helm_selected_line]:sub(1, 3):match('^# .*') then
        helm_selected_line = helm_selected_line + 1
      end

    else
      helm_selected_line = 1

      if helm_matched_items[helm_selected_line]:sub(1, 3) == '' then
        helm_selected_line = 2
      end

      if helm_matched_items[helm_selected_line]:sub(1, 3):match('^# .*') then
        helm_selected_line = helm_selected_line + 1
      end
    end

    api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
  end

  return ''
end
-- }}}
-- Select the previous item -{{{
function helm_prev_item()
  if #helm_matched_items > 1 then
    if helm_selected_line > 1 then

      helm_selected_line = helm_selected_line - 1

      if helm_selected_line == 2 and
        helm_matched_items[1] == '' then

        helm_selected_line = #helm_matched_items
      elseif helm_selected_line > 0 and
        helm_matched_items[helm_selected_line]:sub(1, 3):match('^# .*') then

        helm_selected_line = helm_selected_line - 1
      end

      if helm_selected_line > 0
        and helm_matched_items[helm_selected_line] == '' then

        helm_selected_line = helm_selected_line - 1
      end

      if helm_selected_line == 1 and helm_matched_items[1] == '' then
        helm_selected_line = helm_selected_line + 2
      end

    else
      helm_selected_line = #helm_matched_items
    end

    api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
  end

  return ''
end
-- }}}
-- Goto next region -{{{
function helm_goto_next_region()
  local position = fn.search('^# .*', 'W')

  if position == 0 and helm_matched_items[1] ~= '' then
    helm_selected_line = 1
    api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
  elseif position ~= 0 then
    helm_selected_line = position + 1
    api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
  else
    position = fn.search('^# .*', 'w')

    if position ~= 0 then
      helm_selected_line = position + 1
      api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})
    end
  end
end
-- }}}
-- Goto previous region -{{{
function helm_goto_prev_region()
  local position = fn.search('^$', 'Wb')

  if position > 1 then
    helm_selected_line = position - 1
  else
    position = fn.search('^# .*', 'wb')
    if position ~= 0 then
      helm_selected_line = #helm_matched_items
    end
  end

  api.nvim_win_set_cursor(helm_match_window, {helm_selected_line, 0})

  return ''
end
-- }}}
-- Insert a character -{{{
function helm_insert_char(char)
  helm_before_cursor = helm_before_cursor .. char
  helm_match_pattern = helm_before_cursor .. helm_after_cursor
  helm_increment_cursor()
  helm_render()

  return ''
end
-- }}}
-- Fix the matches list -{{{
function helm_fix_match_list()
  if #helm_match_list > 0 then
    local i = 1

    while i <= #helm_match_list do
      if helm_match_list[i]:match('^# .*') then

        helm_match_list[i] = helm_match_list[i] .. string.rep(' ', vim.o.columns - helm_match_list[i]:len() + 1)

        if helm_match_list[i - 1] ~= nil and helm_match_list[i - 1] ~= '' then
          table.insert(helm_match_list, i, '')
          i = i + 1
        elseif helm_match_list[i - 1] == nil then
          table.insert(helm_match_list, i, '')
          i = i + 1
        end

      else
        helm_match_list[i] = ' ' .. helm_match_list[i]
      end

      i = i + 1
    end

    if helm_match_list[#helm_match_list] ~= '' then
      table.insert(helm_match_list, '')
    end
  end
end
-- }}}
-- Main -{{{
function helm_start(opts)
  helm_match_list = opts.items and opts.items or {}
  helm_prompt = opts.prompt and opts.prompt or helm_default_prompt
  color_matches = opts.matches and opts.matches or {}
  on_enter = opts.on_enter and opts.on_enter or function(s) print(s) end
  local mappings = opts.mappings and opts.mappings or {}

  if #helm_match_list > 0 then
    helm_fix_match_list()
    helm_open_window()

    helm_generate_mappings()
    helm_generate_mappings(mappings)
    helm_render()
  end

  return ''
end
-- }}}
-- Initialize -{{{
vim.cmd('highlight InvisibleCursor gui=reverse blend=100')
vim.cmd('highlight HelmCursor guifg=#161616 guibg=#cc8c3c')

vim.cmd('highlight HelmRegion  guifg=#161616 guibg=#676f84 gui=bold')
vim.cmd('highlight HelmMatch   guifg=#e9ac1e')
vim.cmd('highlight HelmPrompt  guifg=#96a6c8 guibg=#161616')
vim.cmd('highlight HelmWindow  guifg=#ebdbb2 guibg=#161616')
vim.cmd('highlight CursorLine  guibg=#202020')
-- }}}
