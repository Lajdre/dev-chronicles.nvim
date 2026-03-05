local M = {}

local storage_paths = require('dev-chronicles.utils.storage_paths')

function M.log(level, msg)
  vim.fn.writefile({ ('[%s] %s'):format(level, msg) }, storage_paths.get_log_file(), 'a')
end

---@param msg string
---@param level? integer
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

---@param msg string
function M.warn(msg)
  local level = vim.log.levels.WARN
  M.notify('DevChronicles Warning: ' .. msg, level)
  M.log(level, msg)
end

---@param msg string
function M.error(msg)
  local level = vim.log.levels.ERROR
  M.notify('DevChronicles Error: ' .. msg, level)
  M.log(level, msg)
end

---@param msg string
function M.fatal(msg)
  local lvl = vim.log.levels.ERROR
  local full_msg = 'DevChronicles Fatal: ' .. msg
  M.notify(full_msg, lvl)
  M.log(lvl, msg)
  error(full_msg, 2)
end

return M
