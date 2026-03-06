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

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param win_width integer
---@param win_height integer
function M.set_no_data_mess_lines_hl(lines, highlights, win_width, win_height)
  local colors = require('dev-chronicles.core.colors')
  local message = {
    '▀███▀▀▀███                             ██                                      ▄█▀▀▀█▄ ',
    '  ██    ▀█                             ██                                      ██▀  ▀█▄',
    '  ██   █  ▀████████▄█████▄ ▀████████▄██████▀██▀   ▀██▀        ▄▄█▀██▀██▀   ▀██▀     ▄██',
    '  ██████    ██    ██    ██   ██   ▀██  ██    ██   ▄█         ▄█▀   ██ ██   ▄█    ████▀ ',
    '  ██   █  ▄ ██    ██    ██   ██    ██  ██     ██ ▄█          ██▀▀▀▀▀▀  ██ ▄█     ██    ',
    '  ██     ▄█ ██    ██    ██   ██   ▄██  ██      ███     ▄▄    ██▄    ▄   ███      ▄▄    ',
    '▄██████████████  ████  ████▄ ██████▀   ▀████   ▄█      █▄     ▀█████▀   ▄█       ██    ',
    '                             ██              ▄█       ▄█              ▄█               ',
    '                           ▄████▄          ██▀       ▄▀             ██▀                ',
  }

  local n_lines_already_present = #lines
  local available_height = win_height - n_lines_already_present
  local lines_start_index = n_lines_already_present + 1
  local mess_height = #message
  local mess_width = vim.fn.strdisplaywidth(message[1])
  local top_pad = math.floor(
    math.max(lines_start_index, (available_height - mess_height) / 2) + lines_start_index
  )
  local left_pad = string.rep(' ', math.max(0, math.floor((win_width - mess_width) / 2)))

  for i = lines_start_index, top_pad do
    lines[i] = ''
  end

  local index
  for i, line in ipairs(message) do
    index = top_pad + i
    lines[index] = left_pad .. line
    table.insert(highlights, {
      line = index,
      col = 0,
      end_col = -1,
      hl_group = colors.get_or_create_standin_highlight('DevChroniclesRed'),
    })
  end
end

return M
