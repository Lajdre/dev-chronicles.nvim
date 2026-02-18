local M = {}

---Creates a cheap fork of ChroniclesData safe for session updates without
---corrupting the cached source. Only the project matching
---`deep_copy_project_id` is deep-copied (its nested tables get mutated); all
---other projects remain as shared references and must NOT be mutated. The
---returned object is a temporary display-only snapshot, never ment to be
---persisted.
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
