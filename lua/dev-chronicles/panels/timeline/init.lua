local M = {}

local utils = require('dev-chronicles.utils')

---@param data chronicles.ChroniclesData
---@param panel_subtype chronicles.Panel.Subtype
---@param panel_subtype_args chronicles.Panel.Subtype.Args
---@param opts chronicles.Options
---@param session_base chronicles.SessionBase
---@param session_time? integer
---@return chronicles.Panel.Data?
function M.timeline(data, panel_subtype, panel_subtype_args, opts, session_base, session_time)
  local notify = require('dev-chronicles.utils.notify')
  local timeline_data_extraction = require('dev-chronicles.panels.timeline.data_extraction')
  local panels_common = require('dev-chronicles.panels.common')
  local PanelSubtype = require('dev-chronicles.core.enums').PanelSubtype

  ---@type chronicles.Timeline.Data?
  local timeline_data
  ---@type chronicles.Options.Timeline.Section?
  local timeline_type_options

  local start_offset = panel_subtype_args.start_offset
  local end_offset = panel_subtype_args.end_offset

  if not (panels_common.check_offset(start_offset) and panels_common.check_offset(end_offset)) then
    return
  end

  if panel_subtype == PanelSubtype.Days then
    if not opts.track_days.enable then
      notify.warn('track_days option is disabled. Enable it to display day data.')
      return
    end

    timeline_type_options = opts.timeline.timeline_days
    timeline_data = timeline_data_extraction.get_timeline_data_days(
      data,
      session_base.canonical_today_str,
      timeline_type_options.n_by_default,
      timeline_type_options.header.period_indicator,
      timeline_type_options.segment_abbr_labels,
      opts.track_days.optimize_storage_for_x_days,
      start_offset,
      end_offset
    )
  elseif panel_subtype == PanelSubtype.Months then
    timeline_type_options = opts.timeline.timeline_months
    timeline_data = timeline_data_extraction.get_timeline_data_months(
      data,
      session_base,
      timeline_type_options.n_by_default,
      timeline_type_options.header.period_indicator,
      timeline_type_options.segment_abbr_labels,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date
    )
  elseif panel_subtype == PanelSubtype.Years then
    timeline_type_options = opts.timeline.timeline_years
    timeline_data = timeline_data_extraction.get_timeline_data_years(
      data,
      session_base,
      timeline_type_options.n_by_default,
      timeline_type_options.header.period_indicator,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date
    )
  elseif panel_subtype == PanelSubtype.All then
    timeline_type_options = opts.timeline.timeline_all
    timeline_data = timeline_data_extraction.get_timeline_data_all(data, session_base)
  else
    notify.warn(
      string.format(
        "Unrecognized panel subtype for Timeline: '%s'.\nExpected one of: 'Days', 'Months', 'Years', or 'All'.",
        tostring(panel_subtype)
      )
    )
    return
  end

  if not timeline_data then
    return
  end

  local window_dimensions = utils.get_window_dimensions(
    timeline_type_options.window_width,
    timeline_type_options.window_height
  )

  local lines, highlights = M._create_timeline_content(
    timeline_data,
    timeline_type_options,
    window_dimensions.width,
    window_dimensions.height,
    opts,
    session_time
  )

  ---@type chronicles.Panel.Data
  return {
    lines = lines,
    highlights = highlights,
    window_dimensions = window_dimensions,
    buf_name = 'Dev Chronicles Timeline',
    window_title = timeline_type_options.header.window_title,
    window_boarder = nil,
  }
end

---@param timeline_data chronicles.Timeline.Data
---@param timeline_type_opts chronicles.Options.Timeline.Section
---@param win_width integer
---@param win_height integer
---@param plugin_opts chronicles.Options
---@param curr_session_time? integer
---@return string[], chronicles.Highlight[]
function M._create_timeline_content(
  timeline_data,
  timeline_type_opts,
  win_width,
  win_height,
  plugin_opts,
  curr_session_time
)
  local common_content = require('dev-chronicles.panels.common.content')
  local timeline_logic = require('dev-chronicles.panels.timeline.logic')
  local timeline_content = require('dev-chronicles.panels.timeline.content')
  local timeline_opts = plugin_opts.timeline

  local lines = {}
  local highlights = {}

  if timeline_data.segments == nil then
    return timeline_content.handle_no_segments_lines_hl(
      lines,
      highlights,
      timeline_data,
      win_width,
      win_height,
      timeline_type_opts.header
    )
  end

  local header_height = 4
  local footer_height = (timeline_type_opts.segment_numeric_labels.enable and 1 or 0)
    + (timeline_type_opts.segment_abbr_labels.enable and 1 or 0)
  local chart_height = win_height - (header_height + footer_height)
  local horizontal_margin = 2
  local max_chart_width = win_width - (2 * horizontal_margin)
  local vertical_space_for_bars = chart_height - 3 -- time labels row + gap 1 + chart floor
  local n_segments = #timeline_data.segments

  local n_segments_to_keep, chart_left_margin_col =
    require('dev-chronicles.dashboard.logic').calc_chart_stats(
      timeline_type_opts.bar_width,
      timeline_type_opts.bar_spacing,
      max_chart_width,
      n_segments,
      win_width
    )

  if n_segments_to_keep < 1 then
    return timeline_content.handle_no_segments_lines_hl(
      lines,
      highlights,
      timeline_data,
      win_width,
      win_height,
      timeline_type_opts.header
    )
  end

  if n_segments ~= n_segments_to_keep then
    timeline_logic.cut_off_segments(timeline_data, n_segments, n_segments_to_keep)
  end

  local row_repr = utils.get_random_from_tbl(timeline_type_opts.row_repr or timeline_opts.row_repr)
  local row_representation =
    timeline_logic.construct_row_representation(row_repr, timeline_type_opts.bar_width)

  local bar_distribution_data = timeline_logic.construct_bar_distribution_data(
    timeline_data,
    vertical_space_for_bars,
    row_representation.row_codepoint_count,
    chart_left_margin_col,
    timeline_type_opts.bar_width,
    timeline_type_opts.bar_spacing
  )

  local len_lines = 0
  len_lines = timeline_content.set_header_lines_hl(
    lines,
    highlights,
    timeline_data,
    timeline_type_opts.header,
    win_width,
    curr_session_time,
    len_lines
  )

  len_lines = timeline_content.set_time_labels_above_bars_lines_hl(
    lines,
    highlights,
    timeline_data,
    timeline_type_opts.bar_width,
    win_width,
    timeline_type_opts.segment_time_labels,
    bar_distribution_data.bar_left_margin_cols,
    len_lines
  )

  len_lines = timeline_content.set_bars_lines_hl(
    lines,
    highlights,
    timeline_data,
    row_representation,
    bar_distribution_data,
    vertical_space_for_bars,
    chart_left_margin_col,
    timeline_type_opts.bar_spacing,
    win_width
  )

  len_lines = common_content.set_hline_lines_hl(lines, highlights, win_width, nil, nil, len_lines)

  if timeline_type_opts.segment_numeric_labels.enable then
    len_lines = timeline_content.set_numeric_labels_lines_hl(
      lines,
      highlights,
      timeline_data,
      timeline_type_opts.bar_width,
      win_width,
      timeline_type_opts.segment_numeric_labels,
      bar_distribution_data.bar_left_margin_cols,
      len_lines
    )
  end

  if timeline_type_opts.segment_abbr_labels.enable then
    timeline_content.set_abbr_labels_lines_hl(
      lines,
      highlights,
      timeline_data,
      timeline_type_opts.bar_width,
      win_width,
      timeline_type_opts.segment_abbr_labels,
      bar_distribution_data.bar_left_margin_cols,
      len_lines
    )
  end

  return lines, highlights
end

return M
