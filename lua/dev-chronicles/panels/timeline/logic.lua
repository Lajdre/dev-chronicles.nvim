local M = {}

---@param row_repr string
---@param bar_width integer
---@return chronicles.Timeline.RowRepresentation
function M.construct_row_representation(row_repr, bar_width)
  local notify = require('dev-chronicles.utils.notify')
  local string_utils = require('dev-chronicles.utils.strings')

  ---@type integer, integer
  local row_repr_codepoints, row_repr_display_width = vim.str_utfindex(row_repr), 0
  ---@type integer[], integer[]
  local row_char_display_widths, tmp_row_char_display_widths = {}, {}
  ---@type integer[], integer[]
  local row_char_bytes, tmp_row_char_bytes = {}, {}
  ---@type string[], string[]
  local row_chars, tmp_row_chars = {}, {}
  local row_bytes, tmp_row_bytes = 0, 0

  for i = 1, row_repr_codepoints do
    local char = string_utils.str_sub(row_repr, i, i)
    tmp_row_chars[i] = char

    local char_display_width = vim.fn.strdisplaywidth(char)
    row_repr_display_width = row_repr_display_width + char_display_width
    tmp_row_char_display_widths[i] = char_display_width

    local char_bytes = #char
    tmp_row_char_bytes[i] = char_bytes
    tmp_row_bytes = tmp_row_bytes + char_bytes
  end

  local n_to_fill_bar_width

  if row_repr_display_width == bar_width then
    row_char_display_widths = tmp_row_char_display_widths
    row_char_bytes = tmp_row_char_bytes
    row_chars = tmp_row_chars
    row_bytes = tmp_row_bytes
    n_to_fill_bar_width = 1
  else
    n_to_fill_bar_width = bar_width / row_repr_display_width

    if n_to_fill_bar_width ~= math.floor(n_to_fill_bar_width) then
      notify.warn(
        'Provided row_repr row characters: '
          .. row_repr
          .. ' cannot be smoothly expanded to width='
          .. tostring(bar_width)
          .. ' given their display_width='
          .. tostring(row_repr_display_width)
          .. '. Falling back to @ bar representation'
      )
      local fallback_char = '@'
      for i = 1, bar_width do
        row_char_display_widths[i] = 1
        row_chars[i] = fallback_char
      end
      ---@type chronicles.Timeline.RowRepresentation
      return {
        realized_row = fallback_char:rep(bar_width),
        row_codepoint_count = bar_width,
        row_display_width = bar_width,
        row_bytes = bar_width,
        row_chars = row_chars,
        row_char_display_widths = row_char_display_widths,
        row_char_bytes = row_char_display_widths,
      }
    end

    -- The length of tmp_row_char_display_widths should always equal row_repr_codepoints.
    -- Also the length of both row_char_display_widths and row_char_bytes should equal
    -- row_codepoint_count.
    for i = 1, row_repr_codepoints * n_to_fill_bar_width do
      local next_index = ((i - 1) % row_repr_codepoints) + 1
      row_char_display_widths[i] = tmp_row_char_display_widths[((i - 1) % row_repr_codepoints) + 1]

      row_chars[i] = tmp_row_chars[next_index]

      local next_byte_count = tmp_row_char_bytes[((i - 1) % row_repr_codepoints) + 1]
      row_char_bytes[i] = next_byte_count
      row_bytes = row_bytes + next_byte_count
    end
  end

  local realized_row = string.rep(row_repr, n_to_fill_bar_width)
  local row_codepoint_count = row_repr_codepoints * n_to_fill_bar_width

  assert(
    bar_width == row_repr_codepoints * row_repr_display_width * n_to_fill_bar_width,
    'Timeline: construct_row_representation: row_width should equal row_repr_codepoints * row_repr_display_width * n_to_fill_bar_width'
  )

  ---@type chronicles.Timeline.RowRepresentation
  return {
    realized_row = realized_row,
    row_codepoint_count = row_codepoint_count,
    row_display_width = bar_width,
    row_bytes = row_bytes,
    row_chars = row_chars,
    row_char_display_widths = row_char_display_widths,
    row_char_bytes = row_char_bytes,
  }
end

---@param timeline_data chronicles.Timeline.Data
---@param n_segments integer
---@param n_segments_to_keep integer
function M.cut_off_segments(timeline_data, n_segments, n_segments_to_keep)
  ---@type chronicles.Timeline.SegmentData[]
  local kept_segments, len_kept_segments = {}, 0
  local cutoff_start = n_segments - n_segments_to_keep + 1

  for i = cutoff_start, n_segments do
    len_kept_segments = len_kept_segments + 1
    kept_segments[len_kept_segments] = timeline_data.segments[i]
  end

  -- A segment whose `total_segment_time` equals `max_segment_time` could have been cut off
  local max_segment_time = timeline_data.max_segment_time
  for i = 1, cutoff_start - 1 do
    if timeline_data.segments[i].total_segment_time == max_segment_time then
      local new_max_segment_time = 0

      for _, segment_data in ipairs(kept_segments) do
        new_max_segment_time = math.max(segment_data.total_segment_time, new_max_segment_time)
      end

      timeline_data.max_segment_time = new_max_segment_time
      break
    end
  end

  timeline_data.segments = kept_segments
end

---@param timeline_data chronicles.Timeline.Data
---@param vertical_space_for_bars integer
---@param row_codepoint_count integer
---@param chart_left_margin_col integer
---@param bar_width integer
---@param bar_spacing integer
---@return chronicles.Timeline.BarDistributionData
function M.construct_bar_distribution_data(
  timeline_data,
  vertical_space_for_bars,
  row_codepoint_count,
  chart_left_margin_col,
  bar_width,
  bar_spacing
)
  ---@type integer[]
  local bar_heights = {}
  ---@type integer[][]
  local n_project_cells_by_share_by_segment = {}
  ---@type integer[]
  local n_project_cells_by_share_by_segment_index = {}
  ---@type integer[]
  local bar_left_margin_cols = {}
  local max_segment_time = timeline_data.max_segment_time

  for i, segment_data in ipairs(timeline_data.segments) do
    bar_left_margin_cols[i] = chart_left_margin_col + (i - 1) * (bar_width + bar_spacing)

    local bar_height = 0
    if segment_data.total_segment_time > 0 then
      bar_height = math.max(
        1,
        math.floor((segment_data.total_segment_time / max_segment_time) * vertical_space_for_bars)
      )
    end
    bar_heights[i] = bar_height

    local n_available_cells = bar_height * row_codepoint_count

    local cells_assigned = 0
    ---@type integer[]
    local n_project_cells_by_share_by_segment_entry = {}

    local j = 0
    for _, proj_share_data in ipairs(segment_data.project_shares) do
      j = j + 1
      -- Making n_proj_cells at least 1 makes it so that n_proj_cells sum
      -- across segment's projects might be greater than n_available_cells
      -- (very rare). This is fine. Excess cells will be silently discarded.
      -- Example: bar_height=1, bar_width=5, n_projects=6
      local n_proj_cells = math.max(1, math.floor(proj_share_data.share * n_available_cells))
      n_project_cells_by_share_by_segment_entry[j] = n_proj_cells
      cells_assigned = cells_assigned + n_proj_cells
    end

    if cells_assigned < n_available_cells then
      -- Add any deficiency to the project with the highest share (last one, since they are sorted asc)
      n_project_cells_by_share_by_segment_entry[j] = n_project_cells_by_share_by_segment_entry[j]
        + (n_available_cells - cells_assigned)
    end

    if j == 1 then
      -- No need to keep track of cells per project if there is only one project
      n_project_cells_by_share_by_segment_index[i] = -1
      n_project_cells_by_share_by_segment_entry = { 0 }
    else
      n_project_cells_by_share_by_segment_index[i] = 1
    end

    n_project_cells_by_share_by_segment[i] = n_project_cells_by_share_by_segment_entry
  end

  ---@type chronicles.Timeline.BarDistributionData
  return {
    bar_heights = bar_heights,
    n_project_cells_by_share_by_segment = n_project_cells_by_share_by_segment,
    n_project_cells_by_share_by_segment_index = n_project_cells_by_share_by_segment_index,
    bar_left_margin_cols = bar_left_margin_cols,
  }
end

return M
