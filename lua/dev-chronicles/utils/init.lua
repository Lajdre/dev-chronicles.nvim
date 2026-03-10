local M = {
  _seeded_random = false,
}

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

---@generic T: chronicles.Options.Common.Weighted
---@param table T[]
---@return T
function M.get_random_from_tbl(table)
  M._ensure_seeded()
  local n_entries = #table
  local total = 0
  for i = 1, n_entries do
    ---@type chronicles.Options.Common.Weighted
    local entry = table[i]
    total = total + (entry.weight or 1)
  end

  if total == n_entries then
    return table[math.random(1, n_entries)]
  end

  local r = math.random() * total
  local cumulative = 0
  for i = 1, n_entries do
    ---@type chronicles.Options.Common.Weighted
    local entry = table[i]
    cumulative = cumulative + (entry.weight or 1)
    if r <= cumulative then
      return table[i]
    end
  end

  return table[n_entries]
end

---Shuffles a table in-place
---@param tbl any[]
function M.shuffle(tbl)
  M._ensure_seeded()
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
end

function M._ensure_seeded()
  if not M._seeded_random then
    math.randomseed(os.time())
    M._seeded_random = true
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

function M.clear_logs()
  local notify = require('dev-chronicles.utils.notify')
  local storage_paths = require('dev-chronicles.utils.storage_paths')
  local ok, err = require('dev-chronicles.utils.data').clear_file(storage_paths.get_log_file())
  if ok then
    notify.notify('Logs cleared')
  else
    notify.error('Failed to clear logs: ' .. err)
  end
end

return M
