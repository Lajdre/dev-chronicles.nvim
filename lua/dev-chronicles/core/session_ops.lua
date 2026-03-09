local M = {}

---@param project_data chronicles.ChroniclesData.ProjectData
---@param n_days_to_keep integer
---@param now_ts integer
function M.cleanup_project_day_data(project_data, n_days_to_keep, now_ts)
  local time_days = require('dev-chronicles.core.time.days')
  local cutoff_ts = now_ts - (n_days_to_keep * 86400)
  local by_day_data = project_data.by_day

  -- keeps one more day than n_days_to_keep if including today (in case of DTS)
  local new_by_day = {}
  for ts = cutoff_ts, now_ts, 86400 do
    local key = time_days.get_day_str(ts)
    local value = by_day_data[key]
    if value then
      new_by_day[key] = value
    end
  end

  project_data.by_day = new_by_day
  project_data.last_cleaned = now_ts
end

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
    M.apply_changes_to_chronicles_data(data, session_base.changes)
  end

  data_utils.save_data(data, data_file, backup_opts, session_base.now_ts)

  state.abort_session()
end

---@param data chronicles.ChroniclesData
---@param changes chronicles.SessionState.Changes
function M.apply_changes_to_chronicles_data(data, changes)
  for project_id, new_color_or_false in pairs(changes.new_colors or {}) do
    local project_to_change = data.projects[project_id]
    if project_to_change then
      project_to_change.color = new_color_or_false or nil
    end
  end

  for project_id, _ in pairs(changes.to_be_deleted or {}) do
    local project = data.projects[project_id]
    if project then
      data.global_time = data.global_time - project.total_time
      data.projects[project_id] = nil
    end
  end
end

return M
