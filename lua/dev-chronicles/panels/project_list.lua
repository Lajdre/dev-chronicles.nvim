local M = {
  _changes = nil,
  _project_list_left_indent = 2,
  _project_list_right_padding = 1,
}

local colors = require('dev-chronicles.core.colors')
local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
local render = require('dev-chronicles.core.render')
local session_ops = require('dev-chronicles.core.session_ops')
local notify = require('dev-chronicles.utils.notify')
local utils = require('dev-chronicles.utils')

---@param data chronicles.ChroniclesData
---@param opts chronicles.Options
---@return chronicles.Panel.Data?
function M.project_list(data, opts)
  ---@type chronicles.SessionState.Changes
  M._changes = {}
  -- The default mappings for `q` and `<Esc>` are currently not overridden, so
  -- apart from initializing, this line also clears the `_changes` table
  -- between executions. Also the user can quit the window in different ways.

  local lines, highlights, lines_idx, width = {}, {}, 0, 0

  for project_id, _ in pairs(data.projects) do
    lines_idx = lines_idx + 1
    lines[lines_idx] = project_id
  end

  if lines_idx == 0 then
    notify.warn('No projects')
    return
  end

  ---@type chronicles.Panel.Actions
  local actions = {
    ['?'] = function(_)
      M._show_project_help()
    end,
    ['I'] = function(context)
      M._show_project_info(data.projects, context)
    end,
    ['C'] = function(context)
      M._change_project_color(data.projects, context)
    end,
    ['<CR>'] = function(context)
      M._confirm_choices(context.win, data)
    end,
    ['D'] = function(context)
      M._mark_project(data.projects, context, 'D', 'DevChroniclesRed', true, function(project_id)
        if not M._changes.to_be_deleted then
          M._changes.to_be_deleted = {}
        end
        M._changes.to_be_deleted[project_id] = (M._changes.to_be_deleted[project_id] == nil)
            and true
          or nil
      end)
    end,
  }

  table.sort(lines, function(a, b)
    return data.projects[a].total_time > data.projects[b].total_time
  end)

  local indent = string.rep(' ', M._project_list_left_indent)

  for i = 1, lines_idx do
    local line_with_only_proj_name = lines[i]
    local project_color = data.projects[line_with_only_proj_name].color

    local hl_name
    if project_color then
      hl_name = colors.get_or_create_hex_highlight(project_color)
    else
      hl_name = DefaultColors.DevChroniclesAccent
    end

    local line = indent .. lines[i]

    lines[i] = line
    width = math.max(width, #line)

    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = hl_name,
    }
  end

  if opts.project_list.show_help_hint then
    table.insert(lines, '')
    table.insert(lines, 'Press ? for help')
    lines_idx = #lines
    table.insert(highlights, {
      line = lines_idx,
      col = 0,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    })
  end

  width = width + M._project_list_right_padding

  ---@type chronicles.Panel.Data
  return {
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List',
    actions = actions,
    window_dimensions = {
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - lines_idx) * 0.35),
      width = width,
      height = lines_idx,
    },
    cursor_position = {
      row = 1,
      col = 1,
    },
  }
end

function M._show_project_help()
  local lines = {
    'Help | Project List',
    '',
    'Keybindings:',
    '  I     - Show project information',
    "  C     - Change project's color",
    '  D     - Mark project for deletion',
    '  M     - Merge two projects (Not impl.)',
    '  Enter - Confirm changes',
    '  q/Esc - Exit and abort changes',
    '  ?     - Show this help',
    '',
    'Changes are permanently applied upon closing Neovim.',
    '`:DevChronicles abort` discards the changes made.',
    'To check for any queued changes run `:DevChronicles info`.',
    'Disable project_list.show_help_hint to hide the help hint.',
  }

  local max_width, highlights, n_lines = 0, {}, #lines
  for i = 1, n_lines do
    max_width = math.max(max_width, #lines[i])
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    }
  end

  local title = lines[1]
  local title_len = #title
  if title_len < max_width then
    local padding = math.floor((max_width - title_len) / 2)
    lines[1] = string.rep(' ', padding) .. title
  end

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Help',
    window_dimensions = utils.get_window_dimensions_fixed(max_width, n_lines),
  })
end

---@param data_projects chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
function M._show_project_info(data_projects, context)
  local format_time = require('dev-chronicles.core.time').format_time
  local get_day_str = require('dev-chronicles.core.time.days').get_day_str

  local project_data = data_projects[context.line_content:sub(M._project_list_left_indent + 1)]
  if not project_data then
    return
  end

  local lines = {
    'total time:   ' .. format_time(project_data.total_time),
    'last worked:  ' .. get_day_str(project_data.last_worked),
    'first worked: ' .. get_day_str(project_data.first_worked),
    'last cleaned: ' .. get_day_str(project_data.last_cleaned),
    'color:        ' .. tostring(project_data.color),
  }

  if project_data.tags_map then
    local tags = {}
    for tag, _ in pairs(project_data.tags_map) do
      table.insert(tags, tag)
    end

    table.insert(lines, 'tags:         ' .. table.concat(tags, ', '))
  end

  local highlights, n_lines, max_width = {}, #lines, 0
  for i = 1, n_lines do
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    }
    max_width = math.max(max_width, #lines[i])
  end

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Project Info',
    window_dimensions = utils.get_window_dimensions_fixed(max_width, n_lines),
  })
end

---@param data_projects chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
---@param symbol string: char
---@param hl_name string
---@param toggle_selection boolean
---@param callback? function
function M._mark_project(data_projects, context, symbol, hl_name, toggle_selection, callback)
  local project_name = context.line_content:sub(M._project_list_left_indent + 1)
  local project_data = data_projects[project_name]
  if not project_data then
    return
  end

  local marked_line
  if toggle_selection and context.line_content:sub(1, 1) == symbol then
    marked_line = '  ' .. project_name
  else
    marked_line = symbol .. ' ' .. project_name
  end

  local ok, err =
    render.set_lines({ marked_line }, context.buf, context.line_idx - 1, context.line_idx)
  if not ok then
    notify.error('Failed to set buffer lines: ' .. err)
    return
  end

  ---@type chronicles.StringOrFalse?
  local project_color

  if M._changes.new_colors and M._changes.new_colors[project_name] ~= nil then
    project_color = M._changes.new_colors[project_name]
  else
    project_color = project_data.color
  end

  if project_color then
    colors.apply_highlight_hex(context.buf, project_color, context.line_idx - 1, 2, -1)
  else
    colors.apply_highlight(
      context.buf,
      DefaultColors.DevChroniclesAccent,
      context.line_idx - 1,
      2,
      -1
    )
  end

  colors.apply_highlight(context.buf, hl_name, context.line_idx - 1, 0, 1)

  if callback then
    callback(project_name)
  end
end

---@param data_projects chronicles.ChroniclesData.ProjectData[]
---@param context chronicles.Panel.Context
function M._change_project_color(data_projects, context)
  local project_name = context.line_content:sub(M._project_list_left_indent + 1)
  local project_data = data_projects[project_name]
  if not project_data then
    return
  end

  ---@type string?, chronicles.StringOrFalse?
  local current_color, new_color_or_false = project_data.color, nil
  local current_color_line_default, current_color_line_index, current_color_line_default_text_end =
    'Current:  ', 4, 9
  local new_color_line_default, new_color_line_index, new_color_line_default_text_end =
    'New:      ', 5, 4

  local lines = {
    project_name .. ' — Change Color',
    '',
    '',
    current_color_line_default
      .. (current_color and '#' .. current_color .. '  ████████' or 'None'),
    new_color_line_default,
    '',
    '',
    'Input `nil` to remove the existing color',
    'Press C to change the color again',
    'Press Enter to confirm',
    'Press q/Esc to cancel',
  }

  local n_lines, max_width, highlights = #lines, 0, {}
  for i = 1, n_lines do
    max_width = math.max(max_width, #lines[i])
    highlights[i] = {
      line = i,
      col = 0,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    }
  end

  if current_color then
    highlights[n_lines + 1] = {
      line = current_color_line_index,
      col = current_color_line_default_text_end,
      end_col = -1,
      hl_group = colors.get_or_create_hex_highlight(current_color),
    }
  end

  local function prompt(buf)
    vim.ui.input({
      prompt = 'Enter new hex color: ',
    }, function(user_input)
      if not user_input then
        return
      end
      local hex_candidate = colors.check_and_normalize_hex_color(user_input)
      local new_color_line = new_color_line_default

      if hex_candidate then
        new_color_line = new_color_line .. '#' .. hex_candidate .. '  ████████'
        new_color_or_false = hex_candidate
      elseif user_input == 'nil' then
        new_color_line = new_color_line .. 'None'
        new_color_or_false = false
      else
        new_color_line = new_color_line .. 'Not a color: ' .. user_input
      end

      local ok, err =
        render.set_lines({ new_color_line }, buf, new_color_line_index - 1, new_color_line_index)
      if not ok then
        notify.error('Failed to set buffer lines: ' .. err)
        return
      end

      if hex_candidate then
        colors.apply_highlight_hex(
          buf,
          hex_candidate,
          new_color_line_index - 1,
          new_color_line_default_text_end,
          -1
        )

        colors.apply_highlight(
          buf,
          DefaultColors.DevChroniclesAccent,
          new_color_line_index - 1,
          0,
          new_color_line_default_text_end
        )
      else
        colors.apply_highlight(
          buf,
          DefaultColors.DevChroniclesAccent,
          new_color_line_index - 1,
          0,
          -1
        )
      end
    end)
  end

  local function confirm_new_color(win)
    if new_color_or_false == nil then
      notify.warn('Invalid color selected')
      return
    end

    if not M._changes.new_colors then
      M._changes.new_colors = {}
    end
    M._changes.new_colors[project_name] = new_color_or_false

    vim.api.nvim_win_close(win, true)
    M._mark_project(data_projects, context, 'C', 'DevChroniclesBlue', false)
  end

  local buf, _ = render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Change Project Color',
    actions = {
      ['C'] = function(window_context)
        prompt(window_context.buf)
      end,
      ['<CR>'] = function(window_context)
        confirm_new_color(window_context.win)
      end,
    },
    window_dimensions = utils.get_window_dimensions_fixed(max_width, n_lines),
  })

  prompt(buf)
end

---@param win integer
---@param data chronicles.ChroniclesData
function M._confirm_choices(win, data)
  if next(M._changes) == nil then
    notify.warn('Nothing to confim')
    return
  end

  local any_changes = false
  local lines, highlights, lines_idx, max_width, hl_index = {}, {}, 1, 0, 1
  lines[lines_idx] = 'Changes:'
  highlights[hl_index] = {
    line = lines_idx,
    col = 0,
    end_col = -1,
    hl_group = DefaultColors.DevChroniclesAccent,
  }

  if M._changes.new_colors and next(M._changes.new_colors) ~= nil then
    any_changes = true
    lines[lines_idx + 1] = ''
    lines[lines_idx + 2] = 'New project colors:'
    lines_idx = lines_idx + 2
    hl_index = hl_index + 1
    highlights[hl_index] = {
      line = lines_idx,
      col = 0,
      end_col = -1,
      hl_group = colors.get_or_create_standin_highlight('DevChroniclesBlue'),
    }
    max_width = math.max(max_width, #lines[lines_idx])
    for project_id, new_color in pairs(M._changes.new_colors) do
      local color_changes_line = '   ' .. project_id .. ' -> '

      local hl_name
      if not new_color then
        hl_name = DefaultColors.DevChroniclesAccent
        color_changes_line = color_changes_line .. 'None'
      else
        hl_name = colors.get_or_create_hex_highlight(new_color)
        color_changes_line = color_changes_line .. '#' .. new_color
      end

      lines_idx = lines_idx + 1
      lines[lines_idx] = color_changes_line

      hl_index = hl_index + 1
      highlights[hl_index] = {
        line = lines_idx,
        col = 0,
        end_col = -1,
        hl_group = hl_name,
      }
      max_width = math.max(max_width, #lines[lines_idx])
    end
  end

  if M._changes.to_be_deleted and next(M._changes.to_be_deleted) ~= nil then
    any_changes = true
    lines[lines_idx + 1] = ''
    lines[lines_idx + 2] = 'Projects to be deleted:'
    lines_idx = lines_idx + 2

    local hl_red = colors.get_or_create_standin_highlight('DevChroniclesRed')
    hl_index = hl_index + 1
    highlights[hl_index] = {
      line = lines_idx,
      col = 0,
      end_col = -1,
      hl_group = hl_red,
    }

    max_width = math.max(max_width, #lines[lines_idx])
    for project_id, _ in pairs(M._changes.to_be_deleted) do
      lines_idx = lines_idx + 1
      lines[lines_idx] = '   X ' .. project_id

      hl_index = hl_index + 1
      highlights[hl_index] = {
        line = lines_idx,
        col = 0,
        end_col = -1,
        hl_group = hl_red,
      }

      max_width = math.max(max_width, #lines[lines_idx])
    end
  end

  if not any_changes then
    notify.warn('Nothing to confirm')
    return
  end

  lines[lines_idx + 1] = ''
  lines[lines_idx + 2] = ''
  lines[lines_idx + 3] = 'Enter to confirm. q/Esc to cancel'
  lines_idx = lines_idx + 3

  hl_index = hl_index + 1
  highlights[hl_index] = {
    line = lines_idx,
    col = 0,
    end_col = -1,
    hl_group = DefaultColors.DevChroniclesAccent,
  }
  max_width = math.max(max_width, #lines[lines_idx])

  render.render({
    lines = lines,
    highlights = highlights,
    buf_name = 'Dev Chronicles Project List - Confirmation',
    actions = {
      ['<CR>'] = function(context)
        if next(M._changes) == nil then
          notify.warn('Nothing to confirm')
          return
        end

        session_ops.apply_changes_to_chronicles_data(data, M._changes)

        require('dev-chronicles.core.state').set_changes(M._changes)
        M._changes = {}
        vim.api.nvim_win_close(context.win, true)
        vim.api.nvim_win_close(win, true)
      end,
    },
    window_dimensions = utils.get_window_dimensions_fixed(max_width, lines_idx),
  })
end

return M
