local M = {
  ---@type integer
  _namespace = vim.api.nvim_create_namespace('dev-chronicles'),
  ---@type table<string, chronicles.Options.HighlightDefinitions.Definition>
  _lazy_standin_colors = {},
  ---@type string[]
  _lazy_standin_colors_keys = {},
  ---@type table<string, boolean>
  _highlights_cache = {},
  ---@type boolean
  _standin_initialized = false,
  ---@type boolean
  _defaults_initialized = false,
}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors

function M._ensure_standin_colors()
  if M._standin_initialized then
    return
  end

  local standin_colors = {
    { 'DevChroniclesRed', { fg = '#ff6b6b', bold = true } },
    { 'DevChroniclesBlue', { fg = '#5f91fd', bold = true } },
    { 'DevChroniclesGreen', { fg = '#95e1d3', bold = true } },
    { 'DevChroniclesYellow', { fg = '#f9ca24', bold = true } },
    { 'DevChroniclesMagenta', { fg = '#8b008b', bold = true } },
    { 'DevChroniclesPurple', { fg = '#6c5ce7', bold = true } },
    { 'DevChroniclesOrange', { fg = '#ffa500', bold = true } },
    { 'DevChroniclesLightPurple', { fg = '#a29bfe', bold = true } },
    { 'DevChroniclesCyan', { fg = '#37d7ff', bold = true } },
    { 'DevChroniclesPink', { fg = '#ff79c6', bold = true } },
    { 'DevChroniclesLime', { fg = '#a4e635', bold = true } },
    { 'DevChroniclesAmber', { fg = '#ffbf00', bold = true } },
    { 'DevChroniclesCoral', { fg = '#ff8a65', bold = true } },
    { 'DevChroniclesTeal', { fg = '#2dd4bf', bold = true } },
    { 'DevChroniclesSky', { fg = '#38bdf8', bold = true } },
  }

  -- Preserve the order of colors
  for i, entry in ipairs(standin_colors) do
    local name, spec = entry[1], entry[2]
    M._lazy_standin_colors[name] = spec
    M._lazy_standin_colors_keys[i] = name
  end

  M._standin_initialized = true
end

function M._ensure_default_highlights()
  if M._defaults_initialized then
    return
  end

  local highlights = require('dev-chronicles.config').get_opts().highlights
  for hl_name, hl_spec in pairs(highlights) do
    vim.api.nvim_set_hl(0, hl_name, hl_spec)
    M._highlights_cache[hl_name] = true
  end

  M._defaults_initialized = true
end

---@param random_coloring boolean
---@param projects_sorted_ascending boolean
---@param n_projects integer
---@return fun(project_hex_color?: string): string
function M.closure_get_project_highlight(random_coloring, projects_sorted_ascending, n_projects)
  M._ensure_standin_colors()
  local utils = require('dev-chronicles.utils')

  local color_keys = M._lazy_standin_colors_keys
  local n_colors = #color_keys
  local color_index = 1

  if random_coloring then
    utils.shuffle(color_keys)
  end

  ---@param project_hex_color? string
  ---@return string
  return function(project_hex_color)
    if project_hex_color then
      color_index = color_index + 1
      return M.get_or_create_hex_highlight(project_hex_color)
    end

    local hl_name
    if random_coloring then
      -- All colors were used
      if color_index > n_colors then
        utils.shuffle(color_keys)
        color_index = 1
      end
      hl_name = color_keys[color_index]
    else
      -- Sequential color cycling
      hl_name = projects_sorted_ascending
          and color_keys[((n_projects - color_index) % n_colors) + 1]
        or color_keys[((color_index - 1) % n_colors) + 1]
    end

    color_index = color_index + 1

    return M.get_or_create_standin_highlight(hl_name)
  end
end

---@param hex_color string
---@return string
function M.get_or_create_hex_highlight(hex_color)
  local normalized = M.check_and_normalize_hex_color(hex_color)
  if not normalized then
    return DefaultColors.DevChroniclesBackupColor
  end

  local hl_name = 'DevChroniclesCustom' .. normalized:upper()

  if M._highlights_cache[hl_name] then
    return hl_name
  end

  vim.api.nvim_set_hl(0, hl_name, { fg = '#' .. normalized, bold = true })
  M._highlights_cache[hl_name] = true

  return hl_name
end

---@param hl_name string
---@return string
function M.get_or_create_standin_highlight(hl_name)
  M._ensure_standin_colors()
  if M._highlights_cache[hl_name] then
    return hl_name
  end

  local color_specs = M._lazy_standin_colors[hl_name]
  if not color_specs then
    return DefaultColors.DevChroniclesBackupColor
  end

  vim.api.nvim_set_hl(0, hl_name, color_specs)
  M._highlights_cache[hl_name] = true

  return hl_name
end

---@param buf integer
---@param hl_name string
---@param line_idx integer
---@param col integer
---@param end_col integer
function M.apply_highlight(buf, hl_name, line_idx, col, end_col)
  M._ensure_default_highlights()
  hl_name = M.get_or_create_standin_highlight(hl_name)
  vim.api.nvim_buf_add_highlight(buf, M._namespace, hl_name, line_idx, col, end_col)
end

---@param buf integer
---@param hex string
---@param line_idx integer
---@param col integer
---@param end_col integer
function M.apply_highlight_hex(buf, hex, line_idx, col, end_col)
  M._ensure_default_highlights()
  local hl_name = M.get_or_create_hex_highlight(hex)
  vim.api.nvim_buf_add_highlight(buf, M._namespace, hl_name, line_idx, col, end_col)
end

---@param buf integer
---@param highlights chronicles.Highlight[]
function M.apply_highlights(buf, highlights)
  M._ensure_default_highlights()
  local ns = M._namespace
  local add_highlight = vim.api.nvim_buf_add_highlight
  for _, hl in ipairs(highlights) do
    add_highlight(buf, ns, hl.hl_group, hl.line - 1, hl.col, hl.end_col)
  end
end

---@param hex string
---@return string?
function M.check_and_normalize_hex_color(hex)
  local h = hex
    and hex
      :gsub('%s+', '')
      :match('^#?([%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F])$')
  return h and h:lower()
end

return M
