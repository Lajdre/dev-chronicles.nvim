local M = {}

function M.make_dashboard_section(opts)
  ---@type chronicles.Options.Dashboard.Section
  local dashboard_section_opts = {
    header = {
      period_indicator = {
        date_range = true,
        days_count = true,
        time_period_str = nil,
        time_period_str_singular = nil,
      },
      show_current_session_time = true,
      prettify = true,
      window_title = ' Dev Chronicles ',
      total_time = {
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
        format_str = 'total time: %s',
        color = nil, -- TODO: not impl yet
      },
      project_global_time = {
        enable = true,
        show_only_if_differs = true,
        color_like_bars = true,
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
        color = '#b2bec3',
      },
      top_projects = {
        enable = true,
        extra_space_between_bars = false,
        wide_bars = false,
        super_extra_duper_wide_bars = false,
        min_top_projects_len_to_show = 1,
      },
    },
    sorting = {
      enable = true,
      sort_by_last_worked_not_total_time = true,
      ascending = true,
    },
    dynamic_bar_height_thresholds = nil,
    n_by_default = 2,
    random_bars_coloring = false,
    bars_coloring_follows_sorting_in_order = true,
    min_proj_time_to_display_proj = 0,
    window_height = 0.8,
    window_width = 0.8,
    window_border = nil,
    bar_reprs = nil,
    project_total_time = {
      as_hours_max = true,
      as_hours_min = true,
      round_hours_ge_x = 1,
      color_like_bars = true,
      color = nil,
    },
  }

  return vim.tbl_deep_extend('force', dashboard_section_opts, opts or {})
end

function M.make_timeline_section(opts)
  ---@type chronicles.Options.Timeline.Section
  local timeline_section_opts = {
    bar_width = 4,
    bar_spacing = 1,
    row_repr = nil,
    n_by_default = 30,
    window_height = 0.85,
    window_width = 0.99,
    header = {
      total_time = {
        as_hours_max = true,
        as_hours_min = true,
        round_hours_ge_x = 1,
        format_str = 'total time: %s',
        color = nil, -- TODO: not impl yet
      },
      period_indicator = {
        date_range = true,
        days_count = true,
        time_period_str = 'last %s days',
        time_period_str_singular = 'today',
      },
      show_current_session_time = true,
      window_title = ' Dev Chronicles Timeline ',
      project_prefix = '  ',
    },
    segment_time_labels = {
      as_hours_max = true,
      as_hours_min = true,
      round_hours_ge_x = 1,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
    },
    segment_numeric_labels = {
      enable = true,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
    },
    segment_abbr_labels = {
      enable = true,
      color = nil,
      color_like_top_segment_project = true,
      hide_when_empty = false,
      locale = nil,
      date_abbrs = nil,
    },
  }

  return vim.tbl_deep_extend('force', timeline_section_opts, opts or {})
end

return M
