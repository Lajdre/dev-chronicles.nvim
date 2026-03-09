local M = {}

---@type chronicles.SessionState
local session = {
  project_id = nil,
  start_time = nil,
  project_name = nil,
  elapsed_so_far = nil,
  changes = nil,
  is_tracking = false,
}

---@param opts chronicles.Options
function M.start_session(opts)
  if opts.runtime_opts.for_dev_state_override then
    session = opts.runtime_opts.for_dev_state_override
    return
  end

  local project_id, project_name = require('dev-chronicles.core').is_project(
    vim.fn.getcwd(),
    opts.tracked_parent_dirs,
    opts.tracked_dirs,
    opts.exclude_dirs_absolute,
    opts.runtime_opts.parsed_exclude_subdirs_relative_map,
    opts.differentiate_projects_by_folder_not_path
  )

  if project_id and project_name then
    session.project_id = project_id
    session.project_name = project_name
    session.start_time = os.time()
    session.is_tracking = true
  end
end

---The first return value (`SessionBase`) is always present and provides the
---baseline context (needed for both displaying and saving data). The second
---return value (`SessionActive`) is present only if a session is currently
---being tracked; it is also used for both displaying and saving. If it is
---`nil`, no session data will be saved. This approach is used to avoid billions of if
---checks. This function is the global source of truth (non-pure).
---@param extend_today_to_4am boolean
---@return chronicles.SessionBase, chronicles.SessionActive?
function M.get_session_info(extend_today_to_4am)
  local time_days = require('dev-chronicles.core.time.days')
  local time_months = require('dev-chronicles.core.time.months')
  local time_years = require('dev-chronicles.core.time.years')

  local now_ts = os.time()
  local canonical_ts, canonical_today_str =
    time_days.get_canonical_curr_ts_and_day_str(extend_today_to_4am)

  ---@type chronicles.SessionBase
  local session_base = {
    canonical_ts = canonical_ts,
    canonical_today_str = canonical_today_str,
    canonical_month_str = time_months.get_month_str(canonical_ts),
    canonical_year_str = time_years.get_year_str(canonical_ts),
    now_ts = now_ts,
    changes = vim.deepcopy(session.changes),
  }

  if not session.is_tracking then
    return session_base, nil
  end

  local project_id, project_name = session.project_id, session.project_name
  if not (project_id and project_name) then
    require('dev-chronicles.utils.notify').fatal(
      "Session is_tracking is set to true, but it's missing project_id or project_name"
    )
    error()
  end

  local session_time = session.elapsed_so_far or 0
  if session.start_time then -- start_time can be nil if the session was paused and not unpaused afterwards
    session_time = session_time + (now_ts - session.start_time)
  end

  ---@type chronicles.SessionActive
  local session_active = {
    project_id = project_id,
    project_name = project_name,
    session_time = session_time,
    start_time = session.start_time,
    elapsed_so_far = session.elapsed_so_far,
    paused = session.start_time == nil or nil,
  }

  return session_base, session_active
end

function M.abort_session()
  session.is_tracking = false
  session.start_time = nil
  session.project_id = nil
  session.project_name = nil
  session.changes = nil
  session.elapsed_so_far = nil
end

---@param changes chronicles.SessionState.Changes
function M.set_changes(changes)
  session.changes = vim.deepcopy(changes)
end

---@return boolean
function M.pause_session()
  if not session.is_tracking or not session.start_time then
    return false
  end
  session.elapsed_so_far = (session.elapsed_so_far or 0) + (os.time() - session.start_time)
  session.start_time = nil
  return true
end

---@return boolean
function M.unpause_session()
  if not session.is_tracking or session.start_time then
    return false
  end
  session.start_time = os.time()
  return true
end

---@param data_file string
---@param track_days chronicles.Options.TrackDays
---@param min_session_time integer
---@param extend_today_to_4am boolean
---@param backup_opts chronicles.Options.Backup
function M.end_session(data_file, track_days, min_session_time, extend_today_to_4am, backup_opts)
  local session_base, session_active = M.get_session_info(extend_today_to_4am)

  local has_session = session_active and session_active.session_time >= min_session_time
  local has_changes = session_base.changes ~= nil

  if not has_session and not has_changes then
    M.abort_session()
    return
  end

  local data_utils = require('dev-chronicles.utils.data')
  local chronicles_data_ops = require('dev-chronicles.core.chronicles_data_ops')

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

  M.abort_session()
end

return M
