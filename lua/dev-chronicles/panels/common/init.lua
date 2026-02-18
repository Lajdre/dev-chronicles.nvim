local M = {}

local notify = require('dev-chronicles.utils.notify')

---@param offset? integer
---@return boolean
function M.check_offset(offset)
  if offset and (offset < 0 or offset % 1 ~= 0) then
    notify.warn('Offset value needs to be a non-negative integer. Found: ' .. tostring(offset))
    return false
  end
  return true
end

return M
