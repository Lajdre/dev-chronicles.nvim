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

return M
