local M = {}

---Formats project name as a table of strings. The table has at most
---`max_entries` parts. Each part’s length is at most `max_width` wide.
---@param project_name string
---@param max_width integer
---@return table<string>
function M.format_project_name(project_name, max_width, max_entries)
  local parts = M._separate_project_name(project_name)
  local ret = {}
  if max_entries < 1 then
    return ret
  end

  if vim.fn.strdisplaywidth(project_name) <= max_width then
    return { table.concat(parts, ' ') }
  end

  for i, part in ipairs(parts) do
    if i ~= max_entries and vim.fn.strdisplaywidth(part) <= max_width then
      table.insert(ret, part)
    else
      local leftover_string = table.concat(parts, ' ', i)
      for _, str in
        ipairs(M._split_string_given_max_width(leftover_string, max_width, max_entries + 1 - i))
      do
        table.insert(ret, str)
      end
      break
    end
  end

  return ret
end

---Splits a string into `n_splits` parts, with each part being at most `max_width` wide.
---@param str string
---@param max_width integer
---@param n_splits integer
---@return table<string>
function M._split_string_given_max_width(str, max_width, n_splits)
  local ret = {}
  if max_width < 1 or n_splits < 1 then
    return ret
  end

  for i = 1, n_splits do
    if vim.fn.strdisplaywidth(str) > max_width then
      local last_split = (i == n_splits)
      local take = last_split and (max_width - 1) or max_width
      local piece = M.str_sub(str, 1, take)
      if last_split then
        piece = piece .. '…'
      end
      table.insert(ret, piece)
      str = M.str_sub(str, take + 1, -1)
    else
      table.insert(ret, str)
      break
    end
  end

  return ret
end

---Splits `project_name` by `_`, `-`, and `.`
---@param project_name string
---@return string[]
function M._separate_project_name(project_name)
  local result, len_result = {}, 0
  for part in project_name:gmatch('[^%._-]+') do
    len_result = len_result + 1
    result[len_result] = part
  end
  return result
end

---TODO: remove checks
---String substring compatible with multibyte characters.
---Start index: i. End index: j.
-- https://neovim.discourse.group/t/how-do-you-work-with-strings-with-multibyte-characters-in-lua/2437
---@param str string
---@param i integer
---@param j integer
---@return string
function M.str_sub(str, i, j)
  local length = vim.str_utfindex(str)
  if i < 0 then
    i = i + length + 1
  end
  if j and j < 0 then
    j = j + length + 1
  end
  local u = (i > 0) and i or 1
  local v = (j and j <= length) and j or length
  if u > v then
    return ''
  end
  local s = vim.str_byteindex(str, u - 1)
  local e = vim.str_byteindex(str, v)
  return str:sub(s + 1, e)
end

---Extracts project name from its id.
---@param project_id string
---@return string
function M.get_project_name(project_id)
  return project_id:match('([^/]+)/*$') or project_id
end

---@param s string
---@param n integer
---@param sep string
function M.rep_with_sep(s, n, sep)
  if n <= 0 then
    return ''
  end
  local t = {}
  for i = 1, n do
    t[i] = s
  end
  return table.concat(t, sep)
end

---Places a label into a character array. This "simple" variant assumes all
---characters in `label` are single-byte and occupy one cell. Designed as a
---helper for positioning textual labels relative to rendered bars.
---@param target_line_arr string[]
---@param label string
---@param left_margin_col integer
---@param available_width integer
---@param highlights chronicles.Highlight[]
---@param highlights_line integer
---@param highlight? string
function M.place_label_simple(
  target_line_arr,
  label,
  left_margin_col,
  available_width,
  highlights,
  highlights_line,
  highlight
)
  local len_label = #label
  if len_label > available_width then
    return
  end
  local label_left_margin_col = left_margin_col + math.floor((available_width - len_label) / 2)

  for i = 1, len_label do
    target_line_arr[label_left_margin_col + i] = label:sub(i, i)
  end

  if highlight then
    table.insert(highlights, {
      line = highlights_line,
      col = label_left_margin_col,
      end_col = label_left_margin_col + len_label,
      hl_group = highlight,
    })
  end
end

---Returns a closure for positioning textual labels relative to rendered bars.
---The closure automatically manages highlight byte offset across invocations.
---@param target_line_arr string[]
---@param highlights chronicles.Highlight[]
---@param highlights_line integer
---@return fun(label: string, left_margin_col: integer, available_width: integer, highlight: string): nil
function M.closure_place_label(target_line_arr, highlights, highlights_line)
  local hl_bytes_shift = 0

  ---@param label string
  ---@param left_margin_col integer
  ---@param available_width integer
  ---@param highlight? string
  return function(label, left_margin_col, available_width, highlight)
    local label_display_width = vim.fn.strdisplaywidth(label)
    if label_display_width > available_width then
      return
    end

    local label_left_margin_col = left_margin_col
      + math.floor((available_width - label_display_width) / 2)
    local label_curr_col = label_left_margin_col

    for i = 1, vim.str_utfindex(label) do
      local char = M.str_sub(label, i, i)
      local char_disp_width = vim.fn.strdisplaywidth(char)

      label_curr_col = label_curr_col + 1
      target_line_arr[label_curr_col] = char

      for j = 1, char_disp_width - 1 do
        target_line_arr[label_curr_col + j] = ''
      end
      label_curr_col = label_curr_col + char_disp_width - 1
    end

    if highlight then
      local label_bytes = #label

      table.insert(highlights, {
        line = highlights_line,
        col = label_left_margin_col + hl_bytes_shift,
        end_col = label_left_margin_col + label_bytes + hl_bytes_shift,
        hl_group = highlight,
      })

      hl_bytes_shift = hl_bytes_shift + (label_bytes - label_display_width)
    end
  end
end

return M
