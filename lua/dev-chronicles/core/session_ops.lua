local M = {}

---@param data_file string
---@param track_days chronicles.Options.TrackDays
---@param min_session_time integer
---@param extend_today_to_4am boolean
---@param backup_opts chronicles.Options.Backup
function M.end_session(data_file, track_days, min_session_time, extend_today_to_4am, backup_opts)
  local state = require('dev-chronicles.core.state')
  local chronicles_data_ops = require('dev-chronicles.core.chronicles_data_ops')

  local session_base, session_active = state.get_session_info(extend_today_to_4am)

  local has_session = session_active and session_active.session_time >= min_session_time
  local has_changes = session_base.changes ~= nil

  if not has_session and not has_changes then
    state.abort_session()
    return
  end

  local data_utils = require('dev-chronicles.utils.data')
  local data = data_utils.load_data(data_file)
  if not data then
    require('dev-chronicles.utils.notify').error(
      'Recording the session failed. No data returned from load_data()'
    )
    return
  end

  if session_active and has_session then
    chronicles_data_ops.update_chronicles_data_with_session_data(
      data,
      session_active,
      session_base,
      track_days,
      true
    )
  end

  if has_changes then
    chronicles_data_ops.apply_changes_to_chronicles_data(data, session_base.changes)
  end

  data_utils.save_data(data, data_file, backup_opts, session_base.now_ts)

  state.abort_session()
end

return M
