local M = {}

---@param opts chronicles.Options
function M.init(opts)
  require('dev-chronicles.core.commands').setup_commands(opts)
end

---Returns the id and name of the project if the supplied cwd should be
---tracked, otherwise nil. Assumes all paths are absolute and expanded, and all
---dirs end with a slash.
---@param cwd string
---@param tracked_parent_dirs string[]
---@param tracked_dirs string[]
---@param exclude_dirs_absolute string[]
---@param parsed_exclude_subdirs_relative_map table<string, boolean>
---@param differentiate_projects_by_folder_not_path boolean
---@return string?, string?: id, name
function M.is_project(
  cwd,
  tracked_parent_dirs,
  tracked_dirs,
  exclude_dirs_absolute,
  parsed_exclude_subdirs_relative_map,
  differentiate_projects_by_folder_not_path
)
  local utils = require('dev-chronicles.utils')
  local string_utils = require('dev-chronicles.utils.strings')

  cwd = vim.fs.normalize(cwd) .. '/'

  -- Because both end with a slash, if it matches, it cannot be a different dir with
  -- the same prefix
  for _, exclude_path in ipairs(exclude_dirs_absolute) do
    if cwd:find(exclude_path, 1, true) == 1 then
      return
    end
  end

  for _, dir in ipairs(tracked_dirs) do
    if cwd == dir then
      local project_name = string_utils.get_project_name(cwd)
      local project_id = differentiate_projects_by_folder_not_path and project_name
        or utils.unexpand_path(cwd)

      return project_id, project_name
    end
  end

  for _, parent_dir in ipairs(tracked_parent_dirs) do
    if cwd:find(parent_dir, 1, true) == 1 then
      -- Only subdirectories are matched
      if parent_dir == cwd then
        return
      end

      -- Get the first directory after the parent_dir
      local first_dir = cwd:sub(#parent_dir):match('([^/]+)')
      if first_dir then
        if parsed_exclude_subdirs_relative_map[first_dir .. '/'] then
          return
        end

        local full_project_path = parent_dir .. first_dir .. '/'
        local project_id = differentiate_projects_by_folder_not_path and first_dir
          or utils.unexpand_path(full_project_path)

        return project_id, first_dir
      end
    end
  end
end

return M
