local M = {}

---@param panel_data chronicles.Panel.Data
---@return integer buffer, integer window
function M.render(panel_data)
  local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
  local colors = require('dev-chronicles.core.colors')

  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = panel_data.window_dimensions.width,
    height = panel_data.window_dimensions.height,
    row = panel_data.window_dimensions.row,
    col = panel_data.window_dimensions.col,
    style = 'minimal',
    border = panel_data.window_border or 'rounded',
    title = panel_data.window_title,
    title_pos = panel_data.window_title and 'center' or nil,
    focusable = true,
  })

  vim.api.nvim_set_option_value(
    'winhighlight',
    table.concat({
      'NormalFloat:' .. DefaultColors.DevChroniclesWindowBG,
      'FloatBorder:' .. DefaultColors.DevChroniclesWindowBorder,
      'FloatTitle:' .. DefaultColors.DevChroniclesWindowTitle,
    }, ','),
    { win = win }
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, panel_data.lines)

  if panel_data.highlights then
    colors.apply_highlights(buf, panel_data.highlights)
  end

  ---@return chronicles.Panel.Context
  local function get_current_context()
    local line_idx = vim.api.nvim_win_get_cursor(win)[1]
    local line_content = vim.api.nvim_buf_get_lines(buf, line_idx - 1, line_idx, false)[1]
    ---@type chronicles.Panel.Context
    return {
      line_idx = line_idx,
      line_content = line_content,
      buf = buf,
      win = win,
    }
  end

  local opts = { buffer = buf, nowait = true, silent = true }

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, opts)

  if panel_data.actions then
    for key, callback in pairs(panel_data.actions) do
      vim.keymap.set('n', key, function()
        callback(get_current_context())
      end, opts)
    end
  end

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'dev-chronicles', { buf = buf })
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.api.nvim_set_option_value('scrolloff', 0, { win = win })
  vim.api.nvim_set_option_value('sidescrolloff', 0, { win = win })

  vim.api.nvim_buf_set_name(buf, panel_data.buf_name)

  if panel_data.cursor_position then
    vim.api.nvim_win_set_cursor(
      win,
      { panel_data.cursor_position.row, panel_data.cursor_position.col }
    )
  else
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end

  vim.cmd.redraw()
  return buf, win
end

function M.set_lines(lines, buf, start_idx, end_idx)
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  local ok, err = pcall(function()
    vim.api.nvim_buf_set_lines(buf, start_idx, end_idx, false, lines)
  end)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  return ok, err
end

return M
