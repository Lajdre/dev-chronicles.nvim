local M = {
  _initialized = false,
  _storage_paths = nil,
  _cache = nil,
}

---@param storage_paths chronicles.Options.StoragePaths
function M.setup_storage_paths(storage_paths)
  M._storage_paths = storage_paths
  M._initialized = true
  M._cache = {}
end

---@param path string
---@param base string?
---@return string
function M._resolve_path(path, base)
  local normalized = vim.fs.normalize(path)
  if vim.fn.isabsolutepath(normalized) == 1 then
    return normalized
  end
  base = base or vim.fn.stdpath('data')
  return vim.fs.joinpath(base, 'dev-chronicles', normalized)
end

---@param key string
---@param raw_path string
---@param is_dir boolean
---@param base string?
---@return string
function M._get_path(key, raw_path, is_dir, base)
  if not M._initialized then
    error('[dev-chronicles]: storage_paths.init() must be called before accessing paths.')
  end

  if M._cache[key] then
    return M._cache[key]
  end

  local resolved = M._resolve_path(raw_path, base)
  local dir = is_dir and resolved or vim.fn.fnamemodify(resolved, ':h')
  vim.fn.mkdir(dir, 'p')

  M._cache[key] = resolved
  return resolved
end

function M.get_log_file()
  return M._get_path('log_file', M._storage_paths.log_file, false, vim.fn.stdpath('log'))
end

function M.get_data_file()
  return M._get_path('data_file', M._storage_paths.data_file, false)
end

function M.get_backup_dir()
  return M._get_path('backup_dir', M._storage_paths.backup_dir, true)
end

return M
