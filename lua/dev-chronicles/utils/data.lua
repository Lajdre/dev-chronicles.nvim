local M = {}

local notify = require('dev-chronicles.utils.notify')
local uv = vim.uv

---@type {file_path: string?, file_mtime: integer?, data: chronicles.ChroniclesData?}
local chronicles_data_cache = {
  file_path = nil,
  file_mtime = nil,
  data = nil,
}

---@param path string
---@return string?, string?
function M._read_file(path)
  local fd, err = uv.fs_open(path, 'r', 438)
  if not fd then
    return nil, err or 'open failed'
  end

  local stat = uv.fs_fstat(fd)
  if not stat or not (stat.type == 'file' or stat.type == 'link') then
    uv.fs_close(fd)
    return nil, 'not a regular file'
  end

  if stat.size == 0 then
    uv.fs_close(fd)
    return ''
  end

  local data, read_err = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data, read_err
end

---@param file_path string
---@return chronicles.ChroniclesData?
function M.load_data(file_path)
  local file_stat = uv.fs_stat(file_path)
  local current_mtime = file_stat and file_stat.mtime.sec or 0

  if
    current_mtime == chronicles_data_cache.file_mtime
    and chronicles_data_cache.file_path == file_path
    and chronicles_data_cache.data
  then
    return chronicles_data_cache.data
  end

  if vim.fn.filereadable(file_path) == 0 then
    local now_ts = os.time()
    ---@type chronicles.ChroniclesData
    local default = {
      global_time = 0,
      tracking_start = now_ts,
      last_data_write = now_ts,
      schema_version = 1,
      projects = {},
    }
    chronicles_data_cache = { file_path = file_path, file_mtime = 0, data = default }
    return default
  end

  local content, err = M._read_file(file_path)
  if not content then
    notify.error('Failed loading data from disk: ' .. (err or 'read error'))
    return
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    notify.error('Failed loading data from disk: JSON decode failed')
    return
  end

  chronicles_data_cache = {
    file_path = file_path,
    file_mtime = current_mtime,
    data = data,
  }

  return data
end

---@param data chronicles.ChroniclesData
---@param file_path string
function M.save_data(data, file_path)
  local encoded = vim.json.encode(data)
  local tmp = file_path .. '.tmp'

  local fd, open_err = uv.fs_open(tmp, 'w', 438)
  if not fd then
    notify.error('Failed to open temp file: ' .. open_err)
    return
  end

  local write_ok, write_err = uv.fs_write(fd, encoded)
  local close_ok, close_err = uv.fs_close(fd)

  if not (write_ok and close_ok) then
    uv.fs_unlink(tmp)
    notify.error('Failed to write the data to disk: ' .. (write_err or close_err or 'unknown'))
    return
  end

  local rename_ok, rename_err = uv.fs_rename(tmp, file_path)
  if not rename_ok then
    notify.error('Failed to rename temp file: ' .. rename_err)
  end
end

---@param path string
---@param prefix_line string?
---@return string[]?, integer?, integer?
function M.read_file_lines(path, prefix_line)
  local lines, n_lines, max_width = {}, 0, 0

  if vim.fn.filereadable(path) == 0 then
    return lines, n_lines, max_width
  end

  local text, err = M._read_file(path)
  if not text then
    notify.warn('Failed to read ' .. path .. ': ' .. (err or 'no error supplied'))
    return
  end

  if prefix_line then
    n_lines = n_lines + 1
    lines[n_lines] = prefix_line
    max_width = math.max(max_width, #prefix_line)
  end

  for line in text:gmatch('[^\r\n]+') do
    n_lines = n_lines + 1
    lines[n_lines] = line
    max_width = math.max(max_width, #line)
  end
  return lines, n_lines, max_width
end

---@param path string
---@return boolean ok
---@return string? err
function M.clear_file(path)
  local fd, open_err = uv.fs_open(path, 'w', 438)
  if not fd then
    return false, open_err or 'could not open file for writing'
  end

  local _, close_err = uv.fs_close(fd)
  if close_err then
    return false, close_err
  end
  return true
end

return M
