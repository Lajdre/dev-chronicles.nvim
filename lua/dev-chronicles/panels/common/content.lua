local M = {}

local DefaultColors = require('dev-chronicles.core.enums').DefaultColors

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param win_width integer
---@param char? string
---@param hl_group? string
---@param len_lines? integer
---@return integer: len_lines
function M.set_hline_lines_hl(lines, highlights, win_width, char, hl_group, len_lines)
  len_lines = (len_lines or #lines) + 1
  lines[len_lines] = string.rep(char or '▔', win_width)
  table.insert(highlights, {
    line = len_lines,
    col = 0,
    end_col = -1,
    hl_group = hl_group or DefaultColors.DevChroniclesChartFloor,
  })
  return len_lines
end

return M
