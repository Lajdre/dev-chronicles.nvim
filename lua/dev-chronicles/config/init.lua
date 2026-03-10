local M = {}

local checks = require('dev-chronicles.config.checks')
local section_helpers = require('dev-chronicles.config.section_helpers')
local utils = require('dev-chronicles.utils')

---@type chronicles.Options
local options

---@type chronicles.Options.Dashboard.DefaultVars
local default_dashboard_vars = {
  bar_width = 9,
  bar_header_extends_by = 1,
  bar_footer_extends_by = 1,
  bar_spacing = 3,
}

---@type chronicles.Options
local defaults = {
  tracked_parent_dirs = {},
  tracked_dirs = {},
  exclude_subdirs_relative = {},
  exclude_dirs_absolute = {},
  sort_tracked_parent_dirs = false,
  differentiate_projects_by_folder_not_path = true,
  min_session_time = 15,
  track_days = {
    enable = true,
    optimize_storage_for_x_days = 30,
  },
  extend_today_to_4am = true,
  dashboard = {
    bar_width = default_dashboard_vars.bar_width,
    bar_header_extends_by = default_dashboard_vars.bar_header_extends_by,
    bar_footer_extends_by = default_dashboard_vars.bar_footer_extends_by,
    bar_spacing = default_dashboard_vars.bar_spacing,
    bar_reprs = {
      { body = { '▉' } },
    },
    use_extra_default_dashboard_bar_reprs = true,
    dsh_days_today_force_precise_time = true,
    footer = {
      let_proj_names_extend_bars_by_one = true,
    },
    dashboard_days = section_helpers.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Days ',
        period_indicator = {
          time_period_str = 'last %s days',
          time_period_str_singular = 'today',
        },
      },
      n_by_default = 30,
      dynamic_bar_height_thresholds = { 2, 3, 4 },
    }),
    dashboard_months = section_helpers.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Months ',
        top_projects = { wide_bars = true },
      },
      n_by_default = 2,
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
      dynamic_bar_height_thresholds = nil, -- = { 15, 25, 40 },
    }),
    dashboard_years = section_helpers.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles Years ',
        top_projects = { super_extra_duper_wide_bars = true },
      },
      n_by_default = -1,
      sorting = { sort_by_last_worked_not_total_time = false },
      window_border = { '╬', '═', '╬', '║', '╬', '═', '╬', '║' },
    }),
    dashboard_all = section_helpers.make_dashboard_section({
      header = {
        window_title = ' Dev Chronicles All ',
        show_current_session_time = false,
        total_time = {
          format_str = 'global total time: %s',
        },
      },
      sorting = { sort_by_last_worked_not_total_time = false },
      window_height = 0.85,
      window_width = 0.99,
      window_border = { '╳', '━', '╳', '┃', '╳', '━', '╳', '┃' },
    }),
    extra_default_params_bar_reprs = {
      {
        header = { ' ▼ ' },
        body = {
          '███████',
          ' █████ ',
          '  ███  ',
          '  ███  ',
          ' █████ ',
          '███████',
        },
      },
      {
        header = { ' ╔══▣◎▣══╗ ' },
        body = { '║       ║' },
        footer = { ' ╚══▣◎▣══╝ ' },
      },
    },
  },
  timeline = {
    row_reprs = { { body = '█' } },
    timeline_days = section_helpers.make_timeline_section({
      n_by_default = 30,
      window_width = 0.85,
      header = {
        period_indicator = {
          time_period_str = 'last %s days',
          time_period_str_singular = 'today',
        },
        window_title = ' Dev Chronicles Timeline Days ',
      },
      segment_abbr_labels = {
        date_abbrs = { 'su', 'mo', 'tu', 'we', 'th', 'fr', 'sa' },
      },
    }),
    timeline_months = section_helpers.make_timeline_section({
      bar_width = 8,
      n_by_default = 12,
      header = {
        period_indicator = {
          time_period_str = 'last %s months',
          time_period_str_singular = 'this month',
        },
        window_title = ' Dev Chronicles Timeline Months ',
      },
    }),
    timeline_years = section_helpers.make_timeline_section({
      bar_width = 12,
      n_by_default = 2,
      header = {
        period_indicator = {
          time_period_str = 'last %s years',
          time_period_str_singular = 'this years',
        },
        window_title = ' Dev Chronicles Timeline Years ',
      },
      segment_abbr_labels = {
        enable = false,
      },
    }),
    timeline_all = section_helpers.make_timeline_section({
      bar_width = 60,
      header = {
        window_title = ' Dev Chronicles Timeline All',
        show_current_session_time = false,
        total_time = {
          format_str = 'global total time: %s',
        },
      },
      segment_numeric_labels = {
        enable = false,
      },
    }),
  },
  project_list = {
    show_help_hint = true,
  },
  highlights = {
    DevChroniclesAccent = { fg = '#ffffff', bold = true },
    DevChroniclesChartFloor = { fg = '#b2bec3', bold = true },
    DevChroniclesGrayedOut = { fg = '#606065', bold = true },
    DevChroniclesLightGray = { fg = '#d3d3d3', bold = true },
    DevChroniclesWindowBG = { bg = '#100e18' },
    DevChroniclesWindowBorder = { fg = '#d3d3d3', bg = '#100e18', bold = true },
    DevChroniclesWindowTitle = { fg = '#d3d3d3', bg = '#100e18', bold = true },
    DevChroniclesBackupColor = { fg = '#fff588', bold = true },
  },
  backup = {
    interval = 1296000,
    cleanup_interval = 7776000,
    cleanup_n_to_keep = 10,
  },
  runtime_opts = {
    for_dev_state_override = nil,
    parsed_exclude_subdirs_relative_map = nil,
  },
  storage_paths = {
    data_file = 'dev-chronicles.json',
    log_file = 'log.dev-chronicles.log',
    backup_dir = 'backup_dev-chronicles/',
  },
}

---@param opts? chronicles.Options
function M.setup(opts)
  ---@type chronicles.Options
  local merged = vim.tbl_deep_extend('force', defaults, opts or {})

  local function handle_paths_tbl_field(path_field_key, sort)
    local paths_tbl_field = merged[path_field_key]
    for i = 1, #paths_tbl_field do
      paths_tbl_field[i] = utils.expand(paths_tbl_field[i])
    end
    if sort then
      table.sort(paths_tbl_field, function(a, b)
        return #a > #b
      end)
    end
    merged[path_field_key] = paths_tbl_field
  end

  handle_paths_tbl_field('tracked_parent_dirs', merged.sort_tracked_parent_dirs)
  handle_paths_tbl_field('tracked_dirs')
  handle_paths_tbl_field('exclude_dirs_absolute')

  if not merged.runtime_opts.parsed_exclude_subdirs_relative_map then
    ---@type table<string, boolean>
    local parsed_exclude_subdirs_relative_map = {}
    for _, subdir in ipairs(merged.exclude_subdirs_relative) do
      parsed_exclude_subdirs_relative_map[utils.expand(subdir)] = true
    end
    merged.runtime_opts.parsed_exclude_subdirs_relative_map = parsed_exclude_subdirs_relative_map
  end

  if
    merged.dashboard.use_extra_default_dashboard_bar_reprs
    and merged.dashboard.bar_width == default_dashboard_vars.bar_width
    and merged.dashboard.bar_header_extends_by == default_dashboard_vars.bar_header_extends_by
    and merged.dashboard.bar_footer_extends_by == default_dashboard_vars.bar_footer_extends_by
    and merged.dashboard.bar_spacing == default_dashboard_vars.bar_spacing
  then
    for _, extra_bar_repr in ipairs(merged.dashboard.extra_default_params_bar_reprs) do
      table.insert(merged.dashboard.bar_reprs, extra_bar_repr)
    end
  end

  if not checks.check_opts(merged) then
    return
  end

  ---@type chronicles.Options
  options = merged

  require('dev-chronicles.core').init(options)
end

---@return chronicles.Options
function M.get_opts()
  return options
end

---@return chronicles.Options
function M.get_default_opts()
  return defaults
end

return M
