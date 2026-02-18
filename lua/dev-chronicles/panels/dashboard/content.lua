local M = {}

local common_content = require('dev-chronicles.panels.common.content')
local format_time = require('dev-chronicles.core.time').format_time
local DefaultColors = require('dev-chronicles.core.enums').DefaultColors

---Adds 4 line header. Monster function -- TODO: make this not that bad
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param time_period_str string
---@param win_width integer
---@param total_period_time integer
---@param does_include_curr_date boolean
---@param header_dashboard_type_opts chronicles.Options.Dashboard.Header
---@param curr_session_time? integer
---@param top_projects? chronicles.Dashboard.TopProjectsArray
---@param project_id_to_highlight table<string, string>
---@param len_lines? integer
---@return integer: len_lines
function M.set_header_lines_hl(
  lines,
  highlights,
  time_period_str,
  win_width,
  total_period_time,
  does_include_curr_date,
  header_dashboard_type_opts,
  curr_session_time,
  top_projects,
  project_id_to_highlight,
  len_lines
)
  len_lines = len_lines or #lines
  local total_time_opts = header_dashboard_type_opts.total_time
  local left_header = string.format(
    total_time_opts.format_str,
    format_time(
      total_period_time,
      total_time_opts.as_hours_max,
      total_time_opts.as_hours_min,
      total_time_opts.round_hours_ge_x
    )
  )
  if
    header_dashboard_type_opts.show_current_session_time
    and curr_session_time
    and does_include_curr_date
  then
    left_header = left_header .. ' (' .. format_time(curr_session_time, true, false) .. ')'
  end

  local right_header = time_period_str

  local prettify = header_dashboard_type_opts.prettify
  if prettify then
    left_header = '│ ' .. left_header .. ' │'
    right_header = '│ ' .. right_header .. ' │'
  end

  local left_header_disp_width = vim.fn.strdisplaywidth(left_header)
  local right_header_disp_width = vim.fn.strdisplaywidth(right_header)
  local left_header_bytes = #left_header

  local decorator_left = ''
  local decorator_right = ''
  if prettify then
    decorator_left = '╰' .. string.rep('─', left_header_disp_width - 2) .. '╯'
    decorator_right = '╰' .. string.rep('─', right_header_disp_width - 2) .. '╯'
  end
  local decorator_left_bytes = #decorator_left

  local header_line1
  local header_line2
  local right_header_highlight_start_col
  local decorator_right_highlight_start_col

  ---@type integer? -- I know... I didn't want to calculate #top_projects twice
  local len_top_projects = top_projects and #top_projects

  if
    top_projects
    and len_top_projects
    and len_top_projects >= header_dashboard_type_opts.top_projects.min_top_projects_len_to_show
  then
    local use_wide_bars = header_dashboard_type_opts.top_projects.wide_bars
    local use_extra_wide_bars = header_dashboard_type_opts.top_projects.super_extra_duper_wide_bars
    local single_top_bar = use_extra_wide_bars and '▆▆▆'
      or (use_wide_bars and '▆▆' or '▆')
    local single_bottom_bar = use_extra_wide_bars and '▀▀▀'
      or (use_wide_bars and '▀▀' or '▀')
    local bar_disp_width = vim.fn.strdisplaywidth(single_top_bar)
    local single_top_bar_bytes = #single_top_bar
    local space_width = header_dashboard_type_opts.top_projects.extra_space_between_bars and 2 or 1
    local disp_width_per_project = bar_disp_width + space_width

    -- Calculate maximum bars length that can be centered without overlapping headers
    -- For centered bars to not overlap:
    -- start_pos >= len_left_header and end_pos <= win_width - len_right_header
    -- where start_pos = (win_width - bars_length) / 2 and end_pos = start_pos + bars_length
    local max_bars_disp_width =
      math.min(win_width - 2 * left_header_disp_width, win_width - 2 * right_header_disp_width)

    local max_n_projects_by_space =
      math.max(0, math.floor((max_bars_disp_width + space_width) / disp_width_per_project))

    local n_projects_to_show = math.min(max_n_projects_by_space, len_top_projects)

    if n_projects_to_show > 0 then
      local total_bars_disp_width = n_projects_to_show * bar_disp_width
        + (n_projects_to_show - 1) * space_width

      local bars_start_pos = math.floor((win_width - total_bars_disp_width) / 2)

      local top_left_padding = bars_start_pos - left_header_disp_width
      local top_right_padding = win_width
        - right_header_disp_width
        - (bars_start_pos + total_bars_disp_width)
      local bottom_left_padding = bars_start_pos - vim.fn.strdisplaywidth(decorator_left)
      local bottom_right_padding = win_width
        - vim.fn.strdisplaywidth(decorator_right)
        - (bars_start_pos + total_bars_disp_width)

      local top_bars_str =
        string.rep(single_top_bar, n_projects_to_show, string.rep(' ', space_width))
      local top_bars_str_bytes = single_top_bar_bytes * n_projects_to_show
        + (n_projects_to_show - 1) * space_width
      local bottom_bars_str =
        string.rep(single_bottom_bar, n_projects_to_show, string.rep(' ', space_width))

      -- Calculate starting index (truncate top_projects from left if needed)
      local start_idx = len_top_projects - n_projects_to_show + 1

      local curr_highlight_col_top = bars_start_pos + left_header_bytes - left_header_disp_width
      local curr_highlight_col_bottom = bars_start_pos
        + decorator_left_bytes
        - vim.fn.strdisplaywidth(decorator_left)
      local curr_highlight_end_col_top = curr_highlight_col_top
      local curr_highlight_end_col_bottom = curr_highlight_col_bottom

      for i = start_idx, len_top_projects do
        local project_id = top_projects[i]

        -- project_id being false signifies that no projects were worked on
        -- during this period.
        --
        -- A project (project_id) listed in top_projects might not be shown on
        -- screen (for example, if it doesn’t fit on the screen). In that case,
        -- project_id_to_highlight won’t contain it, and a distinct highlight is
        -- used to indicate that this time period had a most-worked-on project
        -- that isn’t currently displayed.
        local color = project_id
            and (project_id_to_highlight[project_id] or DefaultColors.DevChroniclesLightGray)
          or DefaultColors.DevChroniclesGrayedOut

        curr_highlight_end_col_top = curr_highlight_col_top + single_top_bar_bytes
        curr_highlight_end_col_bottom = curr_highlight_col_bottom + single_top_bar_bytes

        table.insert(highlights, {
          line = len_lines + 1,
          col = curr_highlight_col_top,
          end_col = curr_highlight_end_col_top,
          hl_group = color,
        })
        table.insert(highlights, {
          line = len_lines + 2,
          col = curr_highlight_col_bottom,
          end_col = curr_highlight_end_col_bottom,
          hl_group = color,
        })

        curr_highlight_col_top = curr_highlight_end_col_top + space_width
        curr_highlight_col_bottom = curr_highlight_end_col_bottom + space_width
      end

      header_line1 = left_header
        .. string.rep(' ', top_left_padding)
        .. top_bars_str
        .. string.rep(' ', top_right_padding)
        .. right_header

      header_line2 = decorator_left
        .. string.rep(' ', bottom_left_padding)
        .. bottom_bars_str
        .. string.rep(' ', bottom_right_padding)
        .. decorator_right

      right_header_highlight_start_col = left_header_bytes
        + top_left_padding
        + top_bars_str_bytes
        + top_right_padding
      decorator_right_highlight_start_col = decorator_left_bytes
        + bottom_left_padding
        + top_bars_str_bytes
        + top_right_padding
    end
  end

  if not header_line1 then
    -- Either top_projects is nil (not ment to be shown) or no projects from
    -- top_projects can fit.
    local header_padding = win_width - left_header_disp_width - right_header_disp_width

    header_line1 = left_header .. string.rep(' ', header_padding) .. right_header
    header_line2 = prettify
        and (decorator_left .. string.rep(' ', header_padding) .. decorator_right)
      or ''

    right_header_highlight_start_col = left_header_bytes + header_padding
    decorator_right_highlight_start_col = decorator_left_bytes + header_padding
  end

  table.insert(highlights, {
    line = len_lines + 1,
    col = 0,
    end_col = left_header_bytes,
    hl_group = DefaultColors.DevChroniclesAccent,
  })
  table.insert(highlights, {
    line = len_lines + 1,
    col = right_header_highlight_start_col,
    end_col = -1,
    hl_group = DefaultColors.DevChroniclesAccent,
  })
  if prettify then
    table.insert(highlights, {
      line = len_lines + 2,
      col = 0,
      end_col = decorator_left_bytes,
      hl_group = DefaultColors.DevChroniclesAccent,
    })
    table.insert(highlights, {
      line = len_lines + 2,
      col = decorator_right_highlight_start_col,
      end_col = -1,
      hl_group = DefaultColors.DevChroniclesAccent,
    })
  end

  lines[len_lines + 1] = header_line1
  lines[len_lines + 2] = header_line2
  lines[len_lines + 3] = ''
  len_lines = len_lines + 3

  len_lines = common_content.set_hline_lines_hl(
    lines,
    highlights,
    win_width,
    '─',
    DefaultColors.DevChroniclesAccent,
    len_lines
  )

  return len_lines
end

---Adds 2 entries to the lines table. If project_global_time_opts.enable is set to true,
---then it overrides the 3rd lines entry.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param bars_data chronicles.Dashboard.BarData[]
---@param win_width integer
---@param project_total_time_opts chronicles.Options.Dashboard.Section.ProjectTotalTime
---@param project_global_time_opts chronicles.Options.Dashboard.Header.ProjectGlobalTime
---@param len_lines? integer
---@return integer: len_lines
function M.set_time_labels_above_bars_lines_hl(
  lines,
  highlights,
  bars_data,
  win_width,
  project_total_time_opts,
  project_global_time_opts,
  len_lines
)
  local strings = require('dev-chronicles.utils.strings')
  local colors = require('dev-chronicles.core.colors')
  len_lines = len_lines or #lines

  ---@type string[]
  local time_labels_row = vim.split(string.rep(' ', win_width), '')
  local time_labels_as_hours_max = project_total_time_opts.as_hours_max
  local time_labels_as_hours_min = project_total_time_opts.as_hours_min
  local time_labels_round_hours_ge_x = project_total_time_opts.round_hours_ge_x
  local time_labels_color_like_bars = project_total_time_opts.color_like_bars
  local time_labels_row_hl_pos = len_lines + 1
  local time_labels_row_hl = project_total_time_opts.color
      and colors.get_or_create_hex_highlight(project_total_time_opts.color)
    or DefaultColors.DevChroniclesAccent

  ---@type string[]?
  local global_time_labels_row = project_global_time_opts.enable
      and vim.split(string.rep(' ', win_width), '')
    or nil
  local global_time_labels_as_hours_max = project_global_time_opts.as_hours_max
  local global_time_labels_as_hours_min = project_global_time_opts.as_hours_min
  local global_time_labels_round_hours_ge_x = project_global_time_opts.round_hours_ge_x
  local global_time_labels_color_like_bars = project_global_time_opts.color_like_bars
  local global_time_labels_row_index = 3
  local global_time_labels_row_hl = project_global_time_opts.color
      and colors.get_or_create_hex_highlight(project_global_time_opts.color)
    or DefaultColors.DevChroniclesAccent

  for _, bar in ipairs(bars_data) do
    if global_time_labels_row then
      if
        not project_global_time_opts.show_only_if_differs
        or bar.global_project_time ~= bar.project_time
      then
        strings.place_label_simple(
          global_time_labels_row,
          format_time(
            bar.global_project_time,
            global_time_labels_as_hours_max,
            global_time_labels_as_hours_min,
            global_time_labels_round_hours_ge_x
          ),
          bar.left_margin_col,
          bar.width,
          highlights,
          global_time_labels_row_index,
          global_time_labels_color_like_bars and bar.color or global_time_labels_row_hl
        )
      end
    end

    strings.place_label_simple(
      time_labels_row,
      format_time(
        bar.project_time,
        time_labels_as_hours_max,
        time_labels_as_hours_min,
        time_labels_round_hours_ge_x
      ),
      bar.left_margin_col,
      bar.width,
      highlights,
      time_labels_row_hl_pos,
      time_labels_color_like_bars and bar.color or time_labels_row_hl
    )
  end

  if global_time_labels_row then
    lines[global_time_labels_row_index] = table.concat(global_time_labels_row)
  end

  len_lines = len_lines + 1
  lines[len_lines] = table.concat(time_labels_row)
  len_lines = len_lines + 1
  lines[len_lines] = ''

  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param bars_data chronicles.Dashboard.BarData[]
---@param bar_representation chronicles.BarRepresentation
---@param bar_header_extends_by integer
---@param bar_footer_extends_by integer
---@param vertical_space_for_bars integer
---@param bar_width integer
---@param win_width integer
---@param len_lines? integer
---@return integer: len_lines
function M.set_bars_lines_hl(
  lines,
  highlights,
  bars_data,
  bar_representation,
  bar_header_extends_by,
  bar_footer_extends_by,
  vertical_space_for_bars,
  bar_width,
  win_width,
  len_lines
)
  len_lines = len_lines or #lines
  local BarLevel = require('dev-chronicles.core.enums').BarLevel
  local str_sub = require('dev-chronicles.utils.strings').str_sub
  local len_bar_header_rows = #bar_representation.header.realized_rows
  local len_bar_body_rows = #bar_representation.body.realized_rows
  local len_bar_footer_rows = #bar_representation.footer.realized_rows
  local blank_line_chars = vim.split(string.rep(' ', win_width), '')

  for row = vertical_space_for_bars, 1, -1 do
    len_lines = len_lines + 1
    local line_chars = { unpack(blank_line_chars) }
    local hl_bytes_shift = 0

    for _, bar in ipairs(bars_data) do
      if row <= bar.height then
        local offset
        local pos
        local realized_row
        local row_codepoint_counts
        local char_display_widths
        local bar_representation_index

        if bar.current_bar_level == BarLevel.Header then
          offset = bar_header_extends_by
          pos = bar.left_margin_col - offset
          bar_representation_index = bar.curr_bar_representation_index
          realized_row = bar_representation.header.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.header.row_codepoint_counts
          char_display_widths = bar_representation.header.char_display_widths

          if bar_representation_index + 1 > len_bar_header_rows then
            bar.current_bar_level = BarLevel.Body
            bar.curr_bar_representation_index = 1
          else
            bar.curr_bar_representation_index = bar_representation_index + 1
          end
        elseif bar.current_bar_level == BarLevel.Footer or row == len_bar_footer_rows then
          if row == len_bar_footer_rows then
            bar_representation_index = 1
            bar.current_bar_level = BarLevel.Footer
          else
            bar_representation_index = bar.curr_bar_representation_index
          end

          offset = bar_footer_extends_by
          pos = bar.left_margin_col - offset
          realized_row = bar_representation.footer.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.footer.row_codepoint_counts
          char_display_widths = bar_representation.footer.char_display_widths
          bar.curr_bar_representation_index = bar.curr_bar_representation_index + 1
        elseif bar.current_bar_level == BarLevel.Body then
          offset = 0
          pos = bar.left_margin_col
          bar_representation_index = bar.curr_bar_representation_index
          realized_row = bar_representation.body.realized_rows[bar_representation_index]
          row_codepoint_counts = bar_representation.body.row_codepoint_counts
          char_display_widths = bar_representation.body.char_display_widths
          -- bar_representation_index should start from 0 for this to work, but
          -- we want to calculate the next index, so we just don't add 1 to it, since
          -- these would cancel out.
          bar.curr_bar_representation_index = (bar_representation_index % len_bar_body_rows) + 1
        end

        for i = 1, row_codepoint_counts[bar_representation_index] do
          pos = pos + 1
          local char = str_sub(realized_row, i, i)
          line_chars[pos] = char

          local char_disp_width = char_display_widths[bar_representation_index][i]

          for j = 1, char_disp_width - 1 do
            line_chars[pos + j] = ''
          end
          pos = pos + char_disp_width - 1
        end

        -- TODO: I should precalculate that
        local n_bytes_bar_row_str = #realized_row

        -- bar.left_margin_col does not account for multibyte characters and
        -- highlights operate on bytes, so we use hl_bytes_shift to combat that
        table.insert(highlights, {
          line = len_lines,
          col = bar.left_margin_col - offset + hl_bytes_shift,
          end_col = bar.left_margin_col - offset + n_bytes_bar_row_str + hl_bytes_shift,
          hl_group = bar.color,
        })

        -- bar_width equals vim.fn.strdisplaywidth(bar_row_str) for the body
        -- row, enforced in M.construct_bar_string_tbl_representation. If it's
        -- not a body row, then the offset can be non zero, which represents
        -- a bar row being wider than the body row, hence the last term.
        hl_bytes_shift = hl_bytes_shift + n_bytes_bar_row_str - bar_width - (offset * 2)
      end
    end

    lines[len_lines] = table.concat(line_chars)
  end

  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param bars_data chronicles.Dashboard.BarData[]
---@param max_lines_proj_names integer
---@param let_proj_names_extend_bars_by_one boolean
---@param win_width integer
---@param len_lines? integer
---@return integer: len_lines
function M.set_project_names_lines_hl(
  lines,
  highlights,
  bars_data,
  max_lines_proj_names,
  let_proj_names_extend_bars_by_one,
  win_width,
  len_lines
)
  len_lines = len_lines or #lines
  local blank_line_chars = vim.split(string.rep(' ', win_width), '')
  local left_margin_col_offset = let_proj_names_extend_bars_by_one and -1 or 0
  local extra_available_width = let_proj_names_extend_bars_by_one and 2 or 0

  for proj_names_tbl_idx = 1, max_lines_proj_names do
    len_lines = len_lines + 1
    local line_chars = { unpack(blank_line_chars) }
    local place_label =
      require('dev-chronicles.utils.strings').closure_place_label(line_chars, highlights, len_lines)

    for _, bar in ipairs(bars_data) do
      local name_part = bar.project_name_tbl[proj_names_tbl_idx]

      if name_part then
        place_label(
          name_part,
          bar.left_margin_col + left_margin_col_offset,
          bar.width + extra_available_width,
          bar.color
        )
      end
    end

    lines[len_lines] = table.concat(line_chars)
  end

  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param data chronicles.Dashboard.Data
---@param win_width integer
---@param win_height integer
---@param header_dashboard_type_opts chronicles.Options.Dashboard.Header
---@return string[], chronicles.Highlight[]
function M.handle_no_projects_lines_hl(
  lines,
  highlights,
  data,
  win_width,
  win_height,
  header_dashboard_type_opts
)
  M.set_header_lines_hl(
    lines,
    highlights,
    data.time_period_str,
    win_width,
    data.total_period_time,
    data.does_include_curr_date,
    header_dashboard_type_opts,
    nil,
    data.top_projects,
    {}
  )

  require('dev-chronicles.utils').set_no_data_mess_lines_hl(
    lines,
    highlights,
    win_width,
    win_height
  )

  return lines, highlights
end

return M
