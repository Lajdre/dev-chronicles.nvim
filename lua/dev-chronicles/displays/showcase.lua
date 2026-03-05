local M = {}

---@param opts? chronicles.Options
---@param panel_subtype? chronicles.Panel.Subtype
function M.display_showcase(opts, panel_subtype)
  local time_days = require('dev-chronicles.core.time.days')
  local time_months = require('dev-chronicles.core.time.months')
  local time_years = require('dev-chronicles.core.time.years')
  panel_subtype = panel_subtype or require('dev-chronicles.core.enums').PanelSubtype.Days
  opts = opts or require('dev-chronicles.config').get_opts()

  local sample_data, mock_now =
    require('dev-chronicles.utils.sample_data').get_sample_chronicles_data()

  require('dev-chronicles.utils').validate_data({ data = sample_data })

  local canonical_ts, canonical_today_str =
    time_days.get_canonical_curr_ts_and_day_str(opts.extend_today_to_4am, mock_now)

  ---@type chronicles.SessionBase
  local mock_session_base = {
    canonical_ts = canonical_ts,
    canonical_today_str = canonical_today_str,
    canonical_month_str = time_months.get_month_str(canonical_ts),
    canonical_year_str = time_years.get_year_str(canonical_ts),
    now_ts = mock_now,
  }

  local panel_data = require('dev-chronicles.panels.dashboard').dashboard(
    sample_data,
    panel_subtype,
    {},
    opts,
    mock_session_base,
    5400
  )

  if panel_data then
    require('dev-chronicles.core.render').render(panel_data)
  end
end

return M
