local M = {}

local storage_paths = require('dev-chronicles.utils.storage_paths')
local notify = require('dev-chronicles.utils.notify')

---@param data_file string
---@param now_ts integer
---@return boolean
function M.backup_chronicles_data(data_file, now_ts)
  local filename = string.format('dev-chronicles.%s.backup.json', os.date('%Y.%m.%d', now_ts))
  local backup_file = vim.fs.joinpath(storage_paths.get_backup_dir(), filename)

  local ok, err = vim.uv.fs_copyfile(data_file, backup_file)
  if not ok then
    notify.error('[dev-chronicles]: Backup failed: ' .. (err or 'unknown error'))
    return false
  end

  return true
end

return M
