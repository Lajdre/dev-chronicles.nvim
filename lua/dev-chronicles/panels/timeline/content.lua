local M = {}

local common_content = require('dev-chronicles.panels.common.content')
local DefaultColors = require('dev-chronicles.core.enums').DefaultColors
local string_utils = require('dev-chronicles.utils.strings')
local time = require('dev-chronicles.core.time')
local colors = require('dev-chronicles.core.colors')

---Adds 4 entries to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param header_timeline_type_opts chronicles.Options.Timeline.Header
---@param win_width integer
---@param curr_session_time? integer
---@param len_lines? integer
---@return integer: len_lines
function M.set_header_lines_hl(
  lines,
  highlights,
  timeline_data,
  header_timeline_type_opts,
  win_width,
  curr_session_time,
  len_lines
)
  len_lines = len_lines or #lines

  local total_time_opts = header_timeline_type_opts.total_time
  local left_header = '│ '
    .. total_time_opts.format_str:format(
      time.format_time(
        timeline_data.total_period_time,
        total_time_opts.as_hours_max,
        total_time_opts.as_hours_min,
        total_time_opts.round_hours_ge_x
      )
    )

  if
    header_timeline_type_opts.show_current_session_time
    and curr_session_time
    and timeline_data.does_include_curr_date
  then
    left_header = left_header .. ' (' .. time.format_time(curr_session_time, true, false) .. ') │'
  else
    left_header = left_header .. ' │'
  end

  local right_header = '│ ' .. timeline_data.time_period_str .. ' │'

  local left_header_disp_width = vim.fn.strdisplaywidth(left_header)
  local right_header_disp_width = vim.fn.strdisplaywidth(right_header)

  local decorator_left = '╰' .. string.rep('─', left_header_disp_width - 2) .. '╯'
  local decorator_right = '╰' .. string.rep('─', right_header_disp_width - 2) .. '╯'

  local project_prefix = header_timeline_type_opts.project_prefix
  local project_prefix_bytes = #project_prefix
  local project_prefix_disp_width = vim.fn.strdisplaywidth(project_prefix)

  local min_project_entries_pad = 1
  local spacing_between_projects = 1

  local extra_pad_left = math.max(0, right_header_disp_width - left_header_disp_width)
  local extra_pad_right = math.max(0, left_header_disp_width - right_header_disp_width)

  local max_proj_names_disp_width = math.min(
    (win_width - (min_project_entries_pad * 2)) - 2 * left_header_disp_width,
    (win_width - (min_project_entries_pad * 2)) - 2 * right_header_disp_width
  )

  if max_proj_names_disp_width <= 0 then
    lines[len_lines + 1] = ''
    lines[len_lines + 2] = ''
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

  ---@class chronicles.Timeline.HeaderEntry
  ---@field projects_list any[]
  ---@field proj_entries_bytes integer[]
  ---@field proj_entries_highlights any[]
  ---@field len integer
  ---@field max_len integer
  ---@field left_str string
  ---@field right_str string
  ---@field balance_pad_left integer
  ---@field balance_pad_right integer
  ---@field left_str_bytes integer

  ---@type chronicles.Timeline.HeaderEntry[]
  local header_lines = {
    {
      projects_list = {},
      proj_entries_bytes = {},
      proj_entries_highlights = {},
      len = 0,
      max_len = max_proj_names_disp_width,
      left_str = left_header,
      right_str = right_header,
      balance_pad_left = extra_pad_left,
      balance_pad_right = extra_pad_right,
      left_str_bytes = #left_header,
    },
    {
      projects_list = {},
      proj_entries_bytes = {},
      proj_entries_highlights = {},
      len = 0,
      max_len = max_proj_names_disp_width,
      left_str = decorator_left,
      right_str = decorator_right,
      balance_pad_left = extra_pad_left,
      balance_pad_right = extra_pad_right,
      left_str_bytes = #decorator_left,
    },
    {
      projects_list = {},
      proj_entries_bytes = {},
      proj_entries_highlights = {},
      len = 0,
      max_len = win_width - (min_project_entries_pad * 2),
      left_str = '',
      right_str = '',
      balance_pad_left = 0,
      balance_pad_right = 0,
      left_str_bytes = 0,
    },
  }

  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local n_header_lines = #header_lines
  local current_header_line = 1

  for _, project_id in ipairs(timeline_data.sorted_project_ids) do
    local project_name = string_utils.get_project_name(project_id)
    local entry_disp_width = vim.fn.strdisplaywidth(project_name) + project_prefix_disp_width

    while current_header_line <= n_header_lines do
      local header_line = header_lines[current_header_line]
      local total_width = entry_disp_width + (header_line.len > 0 and spacing_between_projects or 0)

      if header_line.len + total_width <= header_line.max_len then
        header_line.len = header_line.len + total_width
        table.insert(header_line.projects_list, project_prefix .. project_name)
        table.insert(header_line.proj_entries_bytes, #project_name + project_prefix_bytes)
        table.insert(header_line.proj_entries_highlights, project_id_to_highlight[project_id])
        break
      else
        current_header_line = current_header_line + 1
      end
    end
  end

  local function calculate_extra_padding(total_width, content_width)
    local extra = total_width - content_width
    if extra <= 0 then
      return 0, 0
    end
    local right = math.floor(extra / 2)
    local left = extra - right -- Left gets any odd remainder
    return left, right
  end

  local spacing_str = (' '):rep(spacing_between_projects)
  local pad_str = (' '):rep(min_project_entries_pad)

  for index, header_line in ipairs(header_lines) do
    if index > 2 and header_line.len == 0 then
      len_lines = len_lines + 1
      lines[len_lines] = ''
      break
    end

    local projects_str = table.concat(header_line.projects_list, spacing_str)
    local center_pad_left, center_pad_right =
      calculate_extra_padding(header_line.max_len, header_line.len)

    local line = header_line.left_str
      .. pad_str
      .. (' '):rep(header_line.balance_pad_left)
      .. (' '):rep(center_pad_left)
      .. projects_str
      .. (' '):rep(center_pad_right)
      .. (' '):rep(header_line.balance_pad_right)
      .. pad_str
      .. header_line.right_str

    len_lines = len_lines + 1
    lines[len_lines] = line

    -- Left decoration highlight
    if header_line.left_str_bytes > 0 then
      table.insert(highlights, {
        line = len_lines,
        col = 0,
        end_col = header_line.left_str_bytes,
        hl_group = DefaultColors.DevChroniclesAccent,
      })
    end

    -- Project entries highlights
    local rolling_col = header_line.left_str_bytes
      + min_project_entries_pad
      + header_line.balance_pad_left
      + center_pad_left

    local len_entries = #header_line.proj_entries_bytes
    for i, entry_bytes in ipairs(header_line.proj_entries_bytes) do
      table.insert(highlights, {
        line = len_lines,
        col = rolling_col,
        end_col = rolling_col + entry_bytes,
        hl_group = header_line.proj_entries_highlights[i],
      })

      rolling_col = rolling_col + entry_bytes
      if i < len_entries then
        rolling_col = rolling_col + spacing_between_projects
      end
    end

    -- Right decoration highlight
    if #header_line.right_str > 0 then
      rolling_col = rolling_col
        + center_pad_right
        + header_line.balance_pad_right
        + min_project_entries_pad

      table.insert(highlights, {
        line = len_lines,
        col = rolling_col,
        end_col = -1,
        hl_group = DefaultColors.DevChroniclesAccent,
      })
    end
  end

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

---Adds 2 entries to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param win_width integer
---@param segment_time_labels_opts chronicles.Options.Timeline.Section.SegmentTimeLabels
---@param bar_left_margin_cols integer[]
---@param len_lines? integer
function M.set_time_labels_above_bars_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  win_width,
  segment_time_labels_opts,
  bar_left_margin_cols,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local time_labels_row_arr = vim.split(string.rep(' ', win_width), '')
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local hide_when_empty = segment_time_labels_opts.hide_when_empty
  local as_hours_max = segment_time_labels_opts.as_hours_max
  local as_hours_min = segment_time_labels_opts.as_hours_min
  local round_hours_ge_x = segment_time_labels_opts.round_hours_ge_x
  local color_like_top_segment_project = segment_time_labels_opts.color_like_top_segment_project
  local orig_highlight = segment_time_labels_opts.color
      and colors.get_or_create_hex_highlight(segment_time_labels_opts.color)
    or DefaultColors.DevChroniclesAccent
  local highlight

  for index, segment_data in ipairs(timeline_data.segments) do
    local total_segment_time = segment_data.total_segment_time

    if not hide_when_empty or total_segment_time > 0 then
      if color_like_top_segment_project then
        local project_shares = segment_data.project_shares
        local len_project_shares = #project_shares
        if len_project_shares > 0 then
          highlight = project_id_to_highlight[project_shares[len_project_shares].project_id]
        else
          highlight = orig_highlight
        end
      end

      string_utils.place_label_simple(
        time_labels_row_arr,
        time.format_time(total_segment_time, as_hours_max, as_hours_min, round_hours_ge_x),
        bar_left_margin_cols[index],
        bar_width,
        highlights,
        len_lines,
        highlight
      )
    end
  end

  lines[len_lines] = table.concat(time_labels_row_arr)
  len_lines = len_lines + 1
  lines[len_lines] = ''

  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param row_representation chronicles.Timeline.RowRepresentation
---@param bar_distribution_data chronicles.Timeline.BarDistributionData
---@param vertical_space_for_bars integer
---@param chart_left_margin_col integer
---@param bar_spacing integer
---@param win_width integer
---@param len_lines? integer
---@return integer: len_lines
function M.set_bars_lines_hl(
  lines,
  highlights,
  timeline_data,
  row_representation,
  bar_distribution_data,
  vertical_space_for_bars,
  chart_left_margin_col,
  bar_spacing,
  win_width,
  len_lines
)
  len_lines = len_lines or #lines
  local blank_line_chars = vim.split(string.rep(' ', win_width), '')
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local row_chars = row_representation.row_chars
  local row_codepoint_count = row_representation.row_codepoint_count
  local row_char_display_widths = row_representation.row_char_display_widths
  local row_char_bytes = row_representation.row_char_bytes
  local row_bytes = row_representation.row_bytes
  local row_width = row_representation.row_display_width
  local bar_heights = bar_distribution_data.bar_heights
  local n_project_cells_by_share_by_segment =
    bar_distribution_data.n_project_cells_by_share_by_segment
  local n_project_cells_by_share_by_segment_index =
    bar_distribution_data.n_project_cells_by_share_by_segment_index

  for row = vertical_space_for_bars, 1, -1 do
    len_lines = len_lines + 1
    local line_chars = { unpack(blank_line_chars) }
    local col = chart_left_margin_col
    local start_col_highlights = chart_left_margin_col

    for index, segment_data in ipairs(timeline_data.segments) do
      if row <= bar_heights[index] then
        local n_project_cells_curr_share_index = n_project_cells_by_share_by_segment_index[index]

        local highlight
        if n_project_cells_curr_share_index == -1 then
          -- Only 1 project entry for this segment
          highlight = project_id_to_highlight[segment_data.project_shares[1].project_id]
        else
          highlight =
            project_id_to_highlight[segment_data.project_shares[n_project_cells_curr_share_index].project_id]
        end

        for i, char in ipairs(row_chars) do
          col = col + 1
          line_chars[col] = char

          local char_disp_width = row_char_display_widths[i]
          for j = 1, char_disp_width - 1 do
            line_chars[col + j] = ''
          end
          col = col + char_disp_width - 1
        end

        if n_project_cells_curr_share_index == -1 then
          table.insert(highlights, {
            line = len_lines,
            col = start_col_highlights,
            end_col = start_col_highlights + row_bytes,
            hl_group = highlight,
          })
        else
          local cells_left_curr_project =
            n_project_cells_by_share_by_segment[index][n_project_cells_curr_share_index]

          local left_cells_after_filling_row = cells_left_curr_project - row_codepoint_count
          if left_cells_after_filling_row >= 0 then
            table.insert(highlights, {
              line = len_lines,
              col = start_col_highlights,
              end_col = start_col_highlights + row_bytes,
              hl_group = highlight,
            })

            n_project_cells_by_share_by_segment[index][n_project_cells_curr_share_index] =
              left_cells_after_filling_row

            if left_cells_after_filling_row == 0 then
              -- This will put the index `n_project_cells_by_share_by_segment_index[index]`
              -- out of bounds of the `timeline_data.segments[index].project_shares` table
              -- when processing the last row of the segment, which is fine.
              n_project_cells_by_share_by_segment_index[index] = n_project_cells_curr_share_index
                + 1
            end
          else
            -- Row cells need to be split between multiple projects
            local local_start_col_highlights = start_col_highlights
            for _, cell_bytes in ipairs(row_char_bytes) do
              table.insert(highlights, {
                line = len_lines,
                col = local_start_col_highlights,
                end_col = local_start_col_highlights + cell_bytes,
                hl_group = highlight,
              })
              local_start_col_highlights = local_start_col_highlights + cell_bytes

              cells_left_curr_project = cells_left_curr_project - 1
              if
                cells_left_curr_project == 0
                and #segment_data.project_shares >= n_project_cells_curr_share_index + 1
              then
                -- This line isn’t strictly required for correct execution, but
                -- it ensures that `n_project_cells_by_share_by_segment` ends
                -- with 0-filled tables once all segment shares are processed.
                -- (Assuming all entries sum to bar_height * bar_width, which
                -- is true 99.9% of the time, but might not be, since
                -- n_proj_cells is capped at a minimum of 1)
                n_project_cells_by_share_by_segment[index][n_project_cells_curr_share_index] =
                  cells_left_curr_project

                n_project_cells_curr_share_index = n_project_cells_curr_share_index + 1
                n_project_cells_by_share_by_segment_index[index] = n_project_cells_curr_share_index

                cells_left_curr_project =
                  n_project_cells_by_share_by_segment[index][n_project_cells_curr_share_index]

                highlight =
                  project_id_to_highlight[segment_data.project_shares[n_project_cells_curr_share_index].project_id]
              end
            end

            n_project_cells_by_share_by_segment[index][n_project_cells_curr_share_index] =
              cells_left_curr_project
          end
        end

        col = col + bar_spacing
        start_col_highlights = start_col_highlights + row_bytes + bar_spacing
      else
        col = col + row_width + bar_spacing
        start_col_highlights = start_col_highlights + row_codepoint_count + bar_spacing
      end
    end

    lines[len_lines] = table.concat(line_chars)
  end

  return len_lines
end

---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param bar_left_margin_cols integer[]
---@param segment_label_base_opts chronicles.Options.Timeline.Section.SegmentLabelBase
---@param get_label fun(segment_data: chronicles.Timeline.SegmentData): string?
---@param place_label fun(label: string?, col: integer, bar_width: integer, hl: string)
function M._fill_label_row(
  timeline_data,
  bar_width,
  bar_left_margin_cols,
  segment_label_base_opts,
  get_label,
  place_label
)
  local opts = segment_label_base_opts
  local project_id_to_highlight = timeline_data.project_id_to_highlight
  local initial_highlight = opts.color and colors.get_or_create_hex_highlight(opts.color)
    or DefaultColors.DevChroniclesAccent
  local highlight = initial_highlight

  for index, segment_data in ipairs(timeline_data.segments) do
    if not opts.hide_when_empty or segment_data.total_segment_time > 0 then
      if opts.color_like_top_segment_project then
        local project_shares = segment_data.project_shares
        local len_ps = #project_shares
        highlight = len_ps > 0 and project_id_to_highlight[project_shares[len_ps].project_id]
          or initial_highlight
      end

      place_label(get_label(segment_data), bar_left_margin_cols[index], bar_width, highlight)
    end
  end
end

---Adds 1 entry to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param win_width integer
---@param numeric_label_opts chronicles.Options.Timeline.Section.SegmentNumericLabels
---@param len_lines? integer
---@param bar_left_margin_cols integer[]
---@return integer: len_lines
function M.set_numeric_labels_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  win_width,
  numeric_label_opts,
  bar_left_margin_cols,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local row_arr = vim.split(string.rep(' ', win_width), '')

  local place_label = function(label, col, avail_width, hl)
    string_utils.place_label_simple(row_arr, label, col, avail_width, highlights, len_lines, hl)
  end

  M._fill_label_row(
    timeline_data,
    bar_width,
    bar_left_margin_cols,
    numeric_label_opts,
    function(seg)
      return seg.day or seg.month or seg.year
    end,
    place_label
  )

  lines[len_lines] = table.concat(row_arr)
  return len_lines
end

---Adds 1 entry to the lines table.
---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param bar_width integer
---@param win_width integer
---@param abbr_label_opts chronicles.Options.Timeline.Section.SegmentAbbrLabels
---@param bar_left_margin_cols integer[]
---@param len_lines? integer
---@return integer: len_lines
function M.set_abbr_labels_lines_hl(
  lines,
  highlights,
  timeline_data,
  bar_width,
  win_width,
  abbr_label_opts,
  bar_left_margin_cols,
  len_lines
)
  len_lines = (len_lines or #lines) + 1
  local row_arr = vim.split(string.rep(' ', win_width), '')

  local place_label = string_utils.closure_place_label(row_arr, highlights, len_lines)

  M._fill_label_row(timeline_data, bar_width, bar_left_margin_cols, abbr_label_opts, function(seg)
    return seg.date_abbr
  end, place_label)

  lines[len_lines] = table.concat(row_arr)
  return len_lines
end

---@param lines string[]
---@param highlights chronicles.Highlight[]
---@param timeline_data chronicles.Timeline.Data
---@param win_width integer
---@param win_height integer
---@param header_timeline_type_opts chronicles.Options.Timeline.Header
---@return string[], chronicles.Highlight[]
function M.handle_no_segments_lines_hl(
  lines,
  highlights,
  timeline_data,
  win_width,
  win_height,
  header_timeline_type_opts
)
  M.set_header_lines_hl(lines, highlights, timeline_data, header_timeline_type_opts, win_width, nil)
  common_content.set_no_data_mess_lines_hl(lines, highlights, win_width, win_height)
  return lines, highlights
end

return M
