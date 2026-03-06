local M = {
  ---@type integer?
  _paused_buf = nil,
  ---@type integer?
  _paused_win = nil,
}

local state = require('dev-chronicles.core.state')
local notify = require('dev-chronicles.utils.notify')

---@param extend_today_to_4am? boolean
function M.display_pause(extend_today_to_4am)
  extend_today_to_4am = extend_today_to_4am
    or require('dev-chronicles.config').get_opts().extend_today_to_4am

  local _, session_active = state.get_session_info(extend_today_to_4am)
  if not session_active then
    notify.notify('Not in a tracked session')
    return
  end

  if session_active.paused then
    M._unpause_session_helper()
    return
  end

  local did_succeed = state.pause_session()
  if did_succeed then
    notify.notify('Paused the session')
  else
    notify.warn('Pausing the session failed')
    return
  end

  local lines, n_lines = { '', ' Paused ', ' ' }, 3
  local max_width = #lines[2]
  local highlights = {
    {
      line = 2,
      col = 0,
      end_col = -1,
      hl_group = require('dev-chronicles.core.enums').DefaultColors.DevChroniclesAccent,
    },
  }

  local actions = {
    ['q'] = function(_)
      M._unpause_session_helper()
    end,
    ['<CR>'] = function(_)
      M._unpause_session_helper()
    end,
  }

  M._paused_buf, M._paused_win = require('dev-chronicles.core.render').render({
    buf_name = 'DevChronicles paused',
    lines = lines,
    actions = actions,
    highlights = highlights,
    window_dimensions = require('dev-chronicles.utils').get_window_dimensions_fixed(
      max_width,
      n_lines
    ),
  })
end

function M._unpause_session_helper()
  local did_succeed = state.unpause_session()
  if did_succeed then
    notify.notify('Unpaused the session')
  else
    notify.warn('Unpausing the session failed')
  end

  if M._paused_win and vim.api.nvim_win_is_valid(M._paused_win) then
    vim.api.nvim_win_close(M._paused_win, true)
    if M._paused_buf and vim.api.nvim_buf_is_valid(M._paused_buf) then
      vim.api.nvim_buf_delete(M._paused_buf, { force = true })
    end
  end

  M._paused_buf, M._paused_win = nil, nil
end

return M
