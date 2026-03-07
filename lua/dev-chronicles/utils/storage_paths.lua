local M = {
  ---@type chronicles.Options.StoragePaths?
  _storage_paths = nil,
}

function M._ensure_storage_paths()
  if not M._storage_paths then
    M._storage_paths = require('dev-chronicles.config').get_opts().storage_paths
  end
end

---@param raw_path string
---@param is_dir boolean
---@param base string?
---@return string
function M._prepare_path(raw_path, is_dir, base)
  local normalized = vim.fs.normalize(raw_path)
  if vim.fn.isabsolutepath(normalized) == 1 then
    return normalized
  end

  base = base or vim.fn.stdpath('data')
  local resolved = vim.fs.joinpath(base, 'dev-chronicles', normalized)

  local dir = is_dir and resolved or vim.fn.fnamemodify(resolved, ':h')
  vim.fn.mkdir(dir, 'p')

  return resolved
end

function M.get_log_file()
  M._ensure_storage_paths()
  local path = M._prepare_path(M._storage_paths.log_file, false, vim.fn.stdpath('log'))
  M.get_log_file = function()
    return path
  end
  return path
end

function M.get_data_file()
  M._ensure_storage_paths()
  local path = M._prepare_path(M._storage_paths.data_file, false)
  M.get_data_file = function()
    return path
  end
  return path
end

function M.get_backup_dir()
  M._ensure_storage_paths()
  local path = M._prepare_path(M._storage_paths.backup_dir, true)
  M.get_backup_dir = function()
    return path
  end
  return path
end

return M
