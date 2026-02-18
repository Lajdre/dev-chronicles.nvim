local M = {}

local common_data_extraction = require('dev-chronicles.panels.common.data_extraction')
local notify = require('dev-chronicles.utils.notify')
local get_project_color =
  require('dev-chronicles.core.colors').closure_get_project_highlight(true, false, -1)
local get_project_name = require('dev-chronicles.utils.strings').get_project_name

---@param data chronicles.ChroniclesData
---@param canonical_today_str string
---@param n_days_by_default integer
---@param period_indicator_opts chronicles.Options.Common.Header.PeriodIndicator
---@param abbr_labels_opts chronicles.Options.Timeline.Section.SegmentAbbrLabels
---@param optimize_storage_for_x_days integer
---@param start_offset? integer
---@param end_offset? integer
---@return chronicles.Timeline.Data?
function M.get_timeline_data_days(
  data,
  canonical_today_str,
  n_days_by_default,
  period_indicator_opts,
  abbr_labels_opts,
  optimize_storage_for_x_days,
  start_offset,
  end_offset
)
  local time_days = require('dev-chronicles.core.time.days')

  start_offset = start_offset or n_days_by_default - 1
  end_offset = end_offset or 0

  local DAY_SEC = 86400
  local start_str = time_days.get_previous_day(canonical_today_str, start_offset)
  local end_str = time_days.get_previous_day(canonical_today_str, end_offset)
  local unnormalized_start_ts = time_days.convert_day_str_to_timestamp(start_str)
  -- Adding half a day should handle DST issues given any reasonable time range. Not pretty, but no overhead.
  local start_ts = unnormalized_start_ts + 43200
  local end_ts = time_days.convert_day_str_to_timestamp(end_str, true)
  local canonical_today_timestamp = time_days.convert_day_str_to_timestamp(canonical_today_str)
  local days_abbrs = abbr_labels_opts.date_abbrs

  if start_ts > end_ts then
    notify.warn(('start (%s) > end (%s)'):format(start_str, end_str))
    return
  end

  if optimize_storage_for_x_days then
    local oldest_allowed_ts = time_days.convert_day_str_to_timestamp(
      time_days.get_previous_day(canonical_today_str, optimize_storage_for_x_days - 1)
    )

    if start_ts < oldest_allowed_ts then
      notify.warn(
        ('start date of the requested period — %s — is older than the last %d stored days (optimize_storage_for_x_days). Since the storage optimization is done lazily, the data past this point could be incorrect. To see it, increase the optimize_storage_for_x_days option.'):format(
          start_str,
          optimize_storage_for_x_days
        )
      )
      return
    end
  end

  local projects =
    common_data_extraction.filter_projects_by_period(data.projects, unnormalized_start_ts, end_ts)

  local orig_locale
  if abbr_labels_opts.locale then
    orig_locale = os.setlocale(nil, 'time')
    os.setlocale(abbr_labels_opts.locale, 'time')
  end

  ---@type chronicles.Timeline.SegmentData[]
  local segments, len_segments = {}, 0
  local max_segment_time = 0
  local total_period_time = 0

  if next(projects) ~= nil then
    for ts = start_ts, end_ts, DAY_SEC do
      ---@type chronicles.Timeline.SegmentData.ProjectShare[]
      local project_shares, len_project_shares = {}, 0
      local total_segment_time = 0
      local key = time_days.get_day_str(ts) -- DD.MM.YYYY
      local day, month, year = key:sub(1, 2), key:sub(4, 5), key:sub(7, 10)
      local dow_abbr = days_abbrs and days_abbrs[os.date('*t', ts).wday] or os.date('%a', ts) --[[@as string]]

      for project_id, project_data in pairs(projects) do
        local day_time = project_data.by_day[key]
        if day_time then
          total_segment_time = total_segment_time + day_time
          len_project_shares = len_project_shares + 1
          project_shares[len_project_shares] = { project_id = project_id, share = day_time }
        end
      end

      if total_segment_time > 0 then
        total_period_time = total_period_time + total_segment_time
        max_segment_time = math.max(max_segment_time, total_segment_time)

        table.sort(project_shares, function(a, b)
          return a.share < b.share
        end)

        for j = 1, len_project_shares do
          project_shares[j].share = project_shares[j].share / total_segment_time
        end
      end

      len_segments = len_segments + 1
      segments[len_segments] = {
        day = day,
        month = month,
        year = year,
        date_abbr = dow_abbr,
        total_segment_time = total_segment_time,
        project_shares = project_shares,
      }
    end
  end

  if abbr_labels_opts.locale then
    os.setlocale(orig_locale, 'time')
  end

  ---@type chronicles.Timeline.Data
  return {
    total_period_time = total_period_time,
    segments = next(segments) ~= nil and segments or nil,
    max_segment_time = max_segment_time,
    does_include_curr_date = canonical_today_timestamp >= unnormalized_start_ts
      and canonical_today_timestamp <= end_ts,
    time_period_str = time_days.get_time_period_str_days(
      start_offset - end_offset + 1,
      start_str,
      end_str,
      canonical_today_str,
      period_indicator_opts
    ),
    project_id_to_highlight = M._construct_project_id_to_highlight(projects),
  }
end

---@param data chronicles.ChroniclesData
---@param session_base chronicles.SessionBase
---@param n_months_by_default integer
---@param period_indicator_opts chronicles.Options.Common.Header.PeriodIndicator
---@param abbr_labels_opts chronicles.Options.Timeline.Section.SegmentAbbrLabels
---@param start_month? string: MM.YYYY
---@param end_month? string: MM.YYYY
---@return chronicles.Timeline.Data?
function M.get_timeline_data_months(
  data,
  session_base,
  n_months_by_default,
  period_indicator_opts,
  abbr_labels_opts,
  start_month,
  end_month
)
  local time_months = require('dev-chronicles.core.time.months')

  start_month = start_month
    or time_months.get_previous_month(session_base.canonical_month_str, n_months_by_default - 1)
  end_month = end_month or session_base.canonical_month_str

  local l_pointer_month, l_pointer_year = time_months.extract_month_year(start_month)
  local r_pointer_month, r_pointer_year = time_months.extract_month_year(end_month)

  local start_ts = time_months.convert_month_str_to_timestamp(start_month)
  local end_ts = time_months.convert_month_str_to_timestamp(end_month, true)
  local months_abbrs = abbr_labels_opts.date_abbrs

  if start_ts > end_ts then
    notify.warn(('start (%s) > end (%s)'):format(start_month, end_month))
    return
  end

  local projects = common_data_extraction.filter_projects_by_period(data.projects, start_ts, end_ts)

  local orig_locale
  if abbr_labels_opts.locale then
    orig_locale = os.setlocale(nil, 'time')
    os.setlocale(abbr_labels_opts.locale, 'time')
  end

  ---@type chronicles.Timeline.SegmentData[]
  local segments, len_segments = {}, 0
  local max_segment_time = 0
  local total_period_time = 0

  if next(projects) ~= nil then
    local i = 0
    while true do
      i = i + 1
      local year_str = string.format('%d', l_pointer_year)
      local month_str = string.format('%02d.%d', l_pointer_month, l_pointer_year)

      ---@type chronicles.Timeline.SegmentData.ProjectShare[]
      local project_shares, len_project_shares = {}, 0
      local total_segment_time = 0

      for project_id, project_data in pairs(projects) do
        local month_time = project_data.by_year[year_str]
          and project_data.by_year[year_str].by_month[month_str]

        if month_time then
          total_segment_time = total_segment_time + month_time
          len_project_shares = len_project_shares + 1
          project_shares[len_project_shares] = { project_id = project_id, share = month_time }
        end
      end

      if total_segment_time > 0 then
        total_period_time = total_period_time + total_segment_time
        max_segment_time = math.max(max_segment_time, total_segment_time)

        table.sort(project_shares, function(a, b)
          return a.share < b.share
        end)

        for j = 1, len_project_shares do
          project_shares[j].share = project_shares[j].share / total_segment_time
        end
      end

      local month_ts = time_months.convert_month_str_to_timestamp(month_str)
      local month_abbr = months_abbrs and months_abbrs[os.date('*t', month_ts).month]
        or os.date('%b', month_ts) --[[@as string]]

      len_segments = len_segments + 1
      segments[len_segments] = {
        day = nil,
        month = month_str:sub(1, 2),
        year = year_str,
        date_abbr = month_abbr,
        total_segment_time = total_segment_time,
        project_shares = project_shares,
      }

      if l_pointer_month == r_pointer_month and l_pointer_year == r_pointer_year then
        break
      end

      l_pointer_month = l_pointer_month + 1
      if l_pointer_month == 13 then
        l_pointer_month = 1
        l_pointer_year = l_pointer_year + 1
      end
    end
  end

  if abbr_labels_opts.locale then
    os.setlocale(orig_locale, 'time')
  end

  ---@type chronicles.Timeline.Data
  return {
    total_period_time = total_period_time,
    segments = next(segments) ~= nil and segments or nil,
    max_segment_time = max_segment_time,
    does_include_curr_date = time_months.is_month_in_range(
      session_base.canonical_month_str,
      start_month,
      end_month
    ),
    time_period_str = time_months.get_time_period_str_months(
      start_month,
      end_month,
      session_base.canonical_month_str,
      session_base.canonical_today_str,
      period_indicator_opts
    ),
    project_id_to_highlight = M._construct_project_id_to_highlight(projects),
  }
end

---@param data chronicles.ChroniclesData
---@param session_base chronicles.SessionBase
---@param n_years_by_default integer
---@param period_indicator_opts chronicles.Options.Common.Header.PeriodIndicator
---@param start_year? string: YYYY
---@param end_year? string: YYYY
---@return chronicles.Timeline.Data?
function M.get_timeline_data_years(
  data,
  session_base,
  n_years_by_default,
  period_indicator_opts,
  start_year,
  end_year
)
  local time_years = require('dev-chronicles.core.time.years')

  start_year = start_year
    or time_years.get_previous_year(session_base.canonical_year_str, n_years_by_default - 1)
  end_year = end_year or session_base.canonical_year_str

  local start_ts = time_years.convert_year_str_to_timestamp(start_year)
  local end_ts = time_years.convert_year_str_to_timestamp(end_year, true)

  if start_ts > end_ts then
    notify.warn(('start year: (%s) > end year: (%s)'):format(start_year, end_year))
    return
  end

  local projects = common_data_extraction.filter_projects_by_period(data.projects, start_ts, end_ts)

  ---@type chronicles.Timeline.SegmentData[]
  local segments, len_segments = {}, 0
  local max_segment_time = 0
  local total_period_time = 0

  local l_pointer_year, r_pointer_year =
    time_years.str_to_year(start_year), time_years.str_to_year(end_year)

  if next(projects) ~= nil then
    local i = 0
    while true do
      i = i + 1
      local year_str = tostring(l_pointer_year)

      ---@type chronicles.Timeline.SegmentData.ProjectShare[]
      local project_shares, len_project_shares = {}, 0
      local total_segment_time = 0

      for project_id, project_data in pairs(projects) do
        local year_time = project_data.by_year[year_str]
          and project_data.by_year[year_str].total_time

        if year_time then
          total_segment_time = total_segment_time + year_time
          len_project_shares = len_project_shares + 1
          project_shares[len_project_shares] = { project_id = project_id, share = year_time }
        end
      end

      if total_segment_time > 0 then
        total_period_time = total_period_time + total_segment_time
        max_segment_time = math.max(max_segment_time, total_segment_time)

        table.sort(project_shares, function(a, b)
          return a.share < b.share
        end)

        for j = 1, len_project_shares do
          project_shares[j].share = project_shares[j].share / total_segment_time
        end
      end

      len_segments = len_segments + 1
      segments[len_segments] = {
        day = nil,
        month = nil,
        year = year_str,
        date_abbr = year_str,
        total_segment_time = total_segment_time,
        project_shares = project_shares,
      }

      if l_pointer_year == r_pointer_year then
        break
      end

      l_pointer_year = l_pointer_year + 1
    end
  end

  ---@type chronicles.Timeline.Data
  return {
    total_period_time = total_period_time,
    segments = next(segments) ~= nil and segments or nil,
    max_segment_time = max_segment_time,
    does_include_curr_date = time_years.is_year_in_range(
      session_base.canonical_year_str,
      start_year,
      end_year
    ),
    time_period_str = time_years.get_time_period_str_years(
      start_year,
      end_year,
      session_base.canonical_year_str,
      session_base.canonical_today_str,
      period_indicator_opts
    ),
    project_id_to_highlight = M._construct_project_id_to_highlight(projects),
  }
end

---@param data chronicles.ChroniclesData
---@param session_base chronicles.SessionBase
---@return chronicles.Timeline.Data?
function M.get_timeline_data_all(data, session_base)
  local time = require('dev-chronicles.core.time')
  local global_time = data.global_time

  ---@type chronicles.Timeline.SegmentData.ProjectShare[]
  local project_shares, len_project_shares = {}, 0

  for project_id, project_data in pairs(data.projects) do
    len_project_shares = len_project_shares + 1
    project_shares[len_project_shares] =
      { project_id = project_id, share = project_data.total_time }
  end

  table.sort(project_shares, function(a, b)
    return a.share < b.share
  end)

  for j = 1, len_project_shares do
    project_shares[j].share = project_shares[j].share / global_time
  end

  ---@type chronicles.Timeline.SegmentData[]
  local segments = {}
  segments[1] = {
    day = nil,
    month = nil,
    year = ' ',
    date_abbr = ' ',
    total_segment_time = global_time,
    project_shares = project_shares,
  }

  ---@type chronicles.Timeline.Data
  return {
    total_period_time = global_time,
    segments = segments,
    max_segment_time = global_time,
    does_include_curr_date = true,
    time_period_str = time.get_time_period_str(data.tracking_start, session_base.now_ts),
    project_id_to_highlight = M._construct_project_id_to_highlight(data.projects),
  }
end

---@param projects chronicles.ChroniclesData.ProjectData
---@return table<string, string>
function M._construct_project_id_to_highlight(projects)
  local project_id_to_highlight = {}
  for project_id, project_data in pairs(projects) do
    project_id_to_highlight[get_project_name(project_id)] = get_project_color(project_data.color)
  end
  return project_id_to_highlight
end

return M
