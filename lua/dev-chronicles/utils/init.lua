local M = {}

---Expand a path and ensure it ends with a slash
---@param path string
---@return string
function M.expand(path)
  local expanded = vim.fn.expand(path)
  if expanded:sub(-1) ~= '/' then
    return expanded .. '/'
  end
  return expanded
end

---If the `path` contains the home directory, replace it with `~`
---@param path string
---@return string
function M.unexpand(path)
  local home = vim.uv.os_homedir()
  if path:sub(1, #home) == home then
    return '~' .. path:sub(#home + 1)
  else
    return path
  end
end

---@generic T
---@param table T[]
---@return T
function M.get_random_from_tbl(table)
  return table[math.random(1, #table)]
end

---Shuffles a table in-place
---@param tbl any[]
function M.shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
end

---@param screen_width_percent number
---@param screen_height_percent number
---@return chronicles.WindowDimensions
function M.get_window_dimensions(screen_width_percent, screen_height_percent)
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local win_width = math.floor(screen_width * screen_width_percent)
  local win_height = math.floor(screen_height * screen_height_percent)
  local win_row = math.floor((screen_height - win_height) / 2)
  local win_col = math.floor((screen_width - win_width) / 2)
  ---@type chronicles.WindowDimensions
  return {
    width = win_width,
    height = win_height,
    row = win_row,
    col = win_col,
  }
end

---@param width number
---@param height number
---@return chronicles.WindowDimensions
function M.get_window_dimensions_fixed(width, height)
  ---@type chronicles.WindowDimensions
  return {
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    width = width,
    height = height,
  }
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

---Sanity check for project times. All months’ times sum to their year’s
---total_time. All years’ times sum to their project’s total_time. All
---projects’ total_time values sum to global_time.
---@param opts? { data_file?: string, data?: chronicles.ChroniclesData }
function M.validate_data(opts)
  local notify = require('dev-chronicles.utils.notify')
  opts = opts or {}

  local data = opts.data
    or require('dev-chronicles.utils.data').load_data(
      opts.data_file or require('dev-chronicles.utils.storage_paths').get_data_file()
    )
  if not data then
    return
  end

  local global_sum = 0

  for project_id, project_data in pairs(data.projects) do
    local years_sum = 0

    for year, year_data in pairs(project_data.by_year) do
      local month_sum = 0
      for _, seconds in pairs(year_data.by_month) do
        month_sum = month_sum + seconds
      end

      if month_sum ~= year_data.total_time then
        notify.warn(
          ('project %s year %s: monthly sum %d != yearly total %d'):format(
            project_id,
            year,
            month_sum,
            year_data.total_time
          )
        )
        return
      end
      years_sum = years_sum + year_data.total_time
    end

    if years_sum ~= project_data.total_time then
      notify.warn(
        ('project %s: yearly sum %d != project total %d'):format(
          project_id,
          years_sum,
          project_data.total_time
        )
      )
      return
    end
    global_sum = global_sum + project_data.total_time
  end

  if global_sum ~= data.global_time then
    notify.warn(('global sum %d != global_time %d'):format(global_sum, data.global_time))
    return
  end
  notify.notify('Data has been validated. Data times are consistent.')
end

return M
