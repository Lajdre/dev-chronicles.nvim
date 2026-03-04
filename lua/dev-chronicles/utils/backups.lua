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

---@param n_to_keep integer
---@return boolean, integer
function M.clear_chronicles_data_backups(n_to_keep)
  local backup_dir = storage_paths.get_backup_dir()
  local handle = vim.uv.fs_scandir(backup_dir)

  if not handle then
    notify.error('[dev-chronicles]: Backup cleanup failed: could not scan backup directory')
    return false, 0
  end

  local backups = {}
  while true do
    local name, ftype = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if ftype == 'file' and name:match('^dev%-chronicles%.%d%d%d%d%.%d%d%.%d%d%.backup%.json$') then
      table.insert(backups, name)
    end
  end

  local backups_len = #backups
  if backups_len <= n_to_keep then
    return true, 0
  end

  table.sort(backups)

  local to_delete = vim.list_slice(backups, 1, backups_len - n_to_keep)
  local deleted = 0

  for _, filename in ipairs(to_delete) do
    local filepath = vim.fs.joinpath(backup_dir, filename)
    local ok, err = vim.uv.fs_unlink(filepath)
    if ok then
      deleted = deleted + 1
    else
      notify.error(
        string.format(
          '[dev-chronicles]: Backup cleanup: failed to delete %s: %s',
          filename,
          err or 'unknown error'
        )
      )
    end
  end

  return deleted == #to_delete, deleted
end

return M
