local M = {}

---@param projects table<string, chronicles.ChroniclesData.ProjectData>
---@param start_ts integer
---@param end_ts integer
---@return table<string, chronicles.ChroniclesData.ProjectData>
function M.filter_projects_by_period(projects, start_ts, end_ts)
  local filtered = {}
  for project_id, project_data in pairs(projects) do
    if project_data.first_worked <= end_ts and project_data.last_worked_canonical >= start_ts then
      filtered[project_id] = project_data
    end
  end
  return filtered
end

return M
