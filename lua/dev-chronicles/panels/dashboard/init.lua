local M = {}

---@param data chronicles.ChroniclesData
---@param panel_subtype chronicles.Panel.Subtype
---@param panel_subtype_args chronicles.Panel.Subtype.Args
---@param opts chronicles.Options
---@param session_base chronicles.SessionBase
---@param session_time? integer
---@return chronicles.Panel.Data?
function M.dashboard(data, panel_subtype, panel_subtype_args, opts, session_base, session_time)
  local notify = require('dev-chronicles.utils.notify')
  local dashboard_data_extraction = require('dev-chronicles.panels.dashboard.data_extraction')
  local panels_common = require('dev-chronicles.panels.common')
  local PanelSubtype = require('dev-chronicles.core.enums').PanelSubtype
  local get_window_dimensions = require('dev-chronicles.utils').get_window_dimensions

  ---@type chronicles.Dashboard.Data?
  local dashboard_data
  ---@type chronicles.Options.Dashboard.Section?
  local dashboard_type_options

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

    if opts.dashboard.dsh_days_today_force_precise_time and start_offset == 0 then
      ---@type chronicles.Options.Dashboard.Section
      dashboard_type_options = vim.deepcopy(opts.dashboard.dashboard_days)
      dashboard_type_options.project_total_time.as_hours_min = false
      dashboard_type_options.project_total_time.round_hours_ge_x = 10
      dashboard_type_options.header.project_global_time.as_hours_min = false
      dashboard_type_options.header.project_global_time.round_hours_ge_x = 10
      dashboard_type_options.header.total_time.as_hours_min = false
      dashboard_type_options.header.total_time.round_hours_ge_x = 10
    else
      dashboard_type_options = opts.dashboard.dashboard_days
    end

    dashboard_data = dashboard_data_extraction.get_dashboard_data_days(
      data,
      session_base.canonical_today_str,
      start_offset,
      end_offset,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.period_indicator,
      dashboard_type_options.header.top_projects.enable,
      opts.track_days.optimize_storage_for_x_days
    )
  elseif panel_subtype == PanelSubtype.All then
    dashboard_type_options = opts.dashboard.dashboard_all
    dashboard_data = dashboard_data_extraction.get_dashboard_data_all(data, session_base)
  elseif panel_subtype == PanelSubtype.Months then
    dashboard_type_options = opts.dashboard.dashboard_months
    dashboard_data = dashboard_data_extraction.get_dashboard_data_months(
      data,
      session_base,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.period_indicator,
      dashboard_type_options.header.top_projects.enable
    )
  elseif panel_subtype == PanelSubtype.Years then
    dashboard_type_options = opts.dashboard.dashboard_years
    dashboard_data = dashboard_data_extraction.get_dashboard_data_years(
      data,
      session_base,
      panel_subtype_args.start_date,
      panel_subtype_args.end_date,
      dashboard_type_options.n_by_default,
      dashboard_type_options.header.period_indicator,
      dashboard_type_options.header.top_projects.enable
    )
  else
    notify.warn('Unrecognised panel subtype for a dashboard: ' .. panel_subtype)
    return
  end

  if not dashboard_data then
    return
  end

  local window_dimensions =
    get_window_dimensions(dashboard_type_options.window_width, dashboard_type_options.window_height)

  local lines, highlights = M._create_dashboard_content(
    dashboard_data,
    dashboard_type_options,
    window_dimensions.width,
    window_dimensions.height,
    opts.dashboard,
    session_time
  )

  ---@type chronicles.Panel.Data
  return {
    lines = lines,
    highlights = highlights,
    window_dimensions = window_dimensions,
    buf_name = 'Dev Chronicles Dashboard',
    window_title = dashboard_type_options.header.window_title,
    window_boarder = dashboard_type_options.window_border,
  }
end

---Creates lines and highlights tables for the dashboard panel
---@param dashboard_data chronicles.Dashboard.Data
---@param dashboard_type_opts chronicles.Options.Dashboard.Section
---@param win_width integer
---@param win_height integer
---@param dashboard_opts chronicles.Options.Dashboard
---@param curr_session_time? integer
---@return string[], chronicles.Highlight[]
function M._create_dashboard_content(
  dashboard_data,
  dashboard_type_opts,
  win_width,
  win_height,
  dashboard_opts,
  curr_session_time
)
  local common_content = require('dev-chronicles.panels.common.content')
  local dashboard_content = require('dev-chronicles.panels.dashboard.content')
  local dashboard_logic = require('dev-chronicles.panels.dashboard.logic')
  local utils = require('dev-chronicles.utils')

  local lines = {}
  local highlights = {}

  local header_height = 4
  local max_footer_height = 3
  local horizontal_margin = 2
  local max_chart_width = win_width - (2 * horizontal_margin)

  local max_project_time = dashboard_data.max_project_time
  local arr_projects = dashboard_data.final_project_data_arr

  if arr_projects == nil then
    return dashboard_content.handle_no_projects_lines_hl(
      lines,
      highlights,
      dashboard_data,
      win_width,
      win_height,
      dashboard_type_opts.header
    )
  end

  local len_arr_projects = #arr_projects

  if dashboard_type_opts.min_proj_time_to_display_proj > 0 then
    arr_projects, len_arr_projects = dashboard_logic.filter_by_min_time(
      arr_projects,
      dashboard_type_opts.min_proj_time_to_display_proj
    )
  end

  local n_projects_to_keep, chart_left_margin_col = dashboard_logic.calc_chart_stats(
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    max_chart_width,
    len_arr_projects,
    win_width
  )

  arr_projects, len_arr_projects, max_project_time = dashboard_logic.sort_and_cut_off_projects(
    arr_projects,
    len_arr_projects,
    n_projects_to_keep,
    max_project_time,
    dashboard_type_opts.sorting
  )

  if len_arr_projects < 1 then
    return dashboard_content.handle_no_projects_lines_hl(
      lines,
      highlights,
      dashboard_data,
      win_width,
      win_height,
      dashboard_type_opts.header
    )
  end

  ---@type string[][], integer
  local project_name_tbls_arr, footer_height = dashboard_logic.get_project_name_tbls_arr(
    arr_projects,
    max_footer_height,
    dashboard_opts.bar_width,
    dashboard_opts.footer.let_proj_names_extend_bars_by_one
  )

  local chart_height = win_height - header_height - footer_height
  local vertical_space_for_bars = chart_height - 3 -- time labels row + gap 1 + chart floor
  local max_bar_height = vertical_space_for_bars

  if dashboard_type_opts.dynamic_bar_height_thresholds then
    max_bar_height = dashboard_logic.calc_max_bar_height(
      vertical_space_for_bars,
      dashboard_type_opts.dynamic_bar_height_thresholds,
      max_project_time
    )
  end

  local bar_repr =
    utils.get_random_from_tbl(dashboard_type_opts.bar_repr_list or dashboard_opts.bar_repr_list)

  local bar_representation = dashboard_logic.construct_bar_representation(
    bar_repr,
    dashboard_opts.bar_width,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by
  )

  ---@type chronicles.Dashboard.BarData[], table<string, string>
  local bars_data, project_id_to_highlight = dashboard_logic.create_bars_data(
    arr_projects,
    project_name_tbls_arr,
    max_project_time,
    max_bar_height,
    chart_left_margin_col,
    dashboard_opts.bar_width,
    dashboard_opts.bar_spacing,
    dashboard_type_opts.random_bars_coloring,
    dashboard_type_opts.bars_coloring_follows_sorting_in_order
        and dashboard_type_opts.sorting.ascending
      or not dashboard_type_opts.sorting.ascending,
    bar_representation.header.realized_rows
  )

  local len_lines = dashboard_content.set_header_lines_hl(
    lines,
    highlights,
    dashboard_data.time_period_str,
    win_width,
    dashboard_data.total_period_time,
    dashboard_data.does_include_curr_date,
    dashboard_type_opts.header,
    curr_session_time,
    dashboard_data.top_projects,
    project_id_to_highlight
  )

  len_lines = dashboard_content.set_time_labels_above_bars_lines_hl(
    lines,
    highlights,
    bars_data,
    win_width,
    dashboard_type_opts.project_total_time,
    dashboard_type_opts.header.project_global_time,
    len_lines
  )

  len_lines = dashboard_content.set_bars_lines_hl(
    lines,
    highlights,
    bars_data,
    bar_representation,
    dashboard_opts.bar_header_extends_by,
    dashboard_opts.bar_footer_extends_by,
    vertical_space_for_bars,
    dashboard_opts.bar_width,
    win_width,
    len_lines
  )

  len_lines = common_content.set_hline_lines_hl(lines, highlights, win_width, nil, nil, len_lines)

  dashboard_content.set_project_names_lines_hl(
    lines,
    highlights,
    bars_data,
    footer_height,
    dashboard_opts.footer.let_proj_names_extend_bars_by_one,
    win_width,
    len_lines
  )

  return lines, highlights
end

return M
