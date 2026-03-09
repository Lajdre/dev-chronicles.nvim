local M = {}

---Creates a cheap fork of ChroniclesData safe for session data updates without
---corrupting the cached source. Only the project matching
---`deep_copy_project_id` is deep-copied in preparation for its fields being
---mutated. All other projects remain as shared references and must NOT be
---mutated internally, although deleting any project by setting it to nil will
---not affect the original data. The returned object is a temporary
---display-only snapshot, never meant to be persisted.
---@param chronicles_data  chronicles.ChroniclesData
---@param deep_copy_project_id string
---@return chronicles.ChroniclesData
function M.fork_chronicles_data_for_session(chronicles_data, deep_copy_project_id)
  local forked = {}
  for k, v in pairs(chronicles_data) do
    forked[k] = v
  end

  local forked_projects = {}
  for k, v in pairs(chronicles_data.projects) do
    forked_projects[k] = v
  end
  forked.projects = forked_projects

  if forked_projects[deep_copy_project_id] then
    forked_projects[deep_copy_project_id] = vim.deepcopy(forked_projects[deep_copy_project_id])
  end

  return forked
end

---Updates ChroniclesData in place with data from the current session.
---@param data chronicles.ChroniclesData
---@param session_active chronicles.SessionActive
---@param session_base chronicles.SessionBase
---@param track_days chronicles.Options.TrackDays
---@param clean_days_data boolean
---@return chronicles.ChroniclesData
function M.update_chronicles_data_with_session_data(
  data,
  session_active,
  session_base,
  track_days,
  clean_days_data
)
  local session_time = session_active.session_time
  local now_ts = session_base.now_ts
  local canonical_ts = session_base.canonical_ts
  local today_key = session_base.canonical_today_str
  local curr_month_key = session_base.canonical_month_str
  local curr_year_key = session_base.canonical_year_str

  local current_project = data.projects[session_active.project_id]
  if not current_project then
    ---@type chronicles.ChroniclesData.ProjectData
    current_project = {
      total_time = 0,
      by_day = {},
      by_year = {},
      first_worked = now_ts,
      last_worked = now_ts,
      last_worked_canonical = canonical_ts,
      last_cleaned = now_ts,
    }
    data.projects[session_active.project_id] = current_project
  end

  local year_data = current_project.by_year[curr_year_key]
  if not year_data then
    year_data = {
      total_time = 0,
      by_month = {},
    }
    current_project.by_year[curr_year_key] = year_data
  end

  data.global_time = data.global_time + session_time
  data.last_data_write = now_ts

  current_project.by_year[curr_year_key].by_month[curr_month_key] = (
    current_project.by_year[curr_year_key].by_month[curr_month_key] or 0
  ) + session_time
  current_project.by_year[curr_year_key].total_time = current_project.by_year[curr_year_key].total_time
    + session_time
  current_project.total_time = current_project.total_time + session_time
  current_project.last_worked = now_ts
  current_project.last_worked_canonical = canonical_ts
  current_project.first_worked = math.min(current_project.first_worked, canonical_ts)

  if track_days.enable then
    current_project.by_day[today_key] = (current_project.by_day[today_key] or 0) + session_time

    if clean_days_data and track_days.optimize_storage_for_x_days then
      local should_clean = now_ts - current_project.last_cleaned >= 2592000
      if should_clean then
        M.cleanup_project_day_data(current_project, track_days.optimize_storage_for_x_days, now_ts)
      end
    end
  end

  return data
end

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
