---@meta

---@alias chronicles.Panel.Type
---| 'Dashboard'
---| 'Timeline'
---| 'Stats'
---| 'List'

---@alias chronicles.Panel.Subtype
---| 'Days'
---| 'Months'
---| 'Years'
---| 'All'

---@alias chronicles.BarLevel
---| 'Header'
---| 'Body'
---| 'Footer'

---@alias chronicles.StringOrFalse string|false

---@class chronicles.SessionState.Changes
---@field new_colors? table<string, chronicles.StringOrFalse>
---@field to_be_deleted? table<string, boolean>

---@class chronicles.SessionState
---@field project_id? string
---@field project_name? string
---@field start_time? integer
---@field elapsed_so_far? integer
---@field changes? chronicles.SessionState.Changes
---@field is_tracking boolean

---@class chronicles.SessionBase
---@field canonical_ts integer
---@field canonical_today_str string
---@field canonical_month_str string
---@field canonical_year_str string
---@field now_ts integer
---@field changes? chronicles.SessionState.Changes

---@class chronicles.SessionActive
---@field project_id string
---@field project_name string
---@field session_time integer
---@field start_time? integer
---@field elapsed_so_far? integer
---@field paused? boolean

---@class chronicles.Panel.Subtype.Args
---@field start_offset? integer
---@field end_offset? integer
---@field start_date? string
---@field end_date? string

---@class chronicles.Dashboard.FinalProjectData
---@field project_id string
---@field total_time integer
---@field last_worked integer
---@field last_worked_canonical integer
---@field first_worked integer
---@field global_time integer
---@field color? string
---@field tags_map? table<string, any>

---@alias chronicles.Dashboard.FinalProjectDataMap table<string, chronicles.Dashboard.FinalProjectData>

---@class chronicles.Dashboard.Data
---@field global_time integer
---@field total_period_time integer
---@field final_project_data_arr? chronicles.Dashboard.FinalProjectData[]
---@field max_project_time integer
---@field does_include_curr_date boolean
---@field time_period_str string
---@field top_projects? chronicles.Dashboard.TopProjectsArray

---@class chronicles.Dashboard.BarData
---@field project_name_tbl string[]
---@field project_time integer
---@field height  integer
---@field color string
---@field left_margin_col integer
---@field width integer
---@field current_bar_level chronicles.BarLevel
---@field curr_bar_representation_index integer
---@field global_project_time integer

---@class chronicles.BarLevelRepresentation
---@field realized_rows string[]
---@field row_codepoint_counts integer[]
---@field char_display_widths integer[][]

---@class chronicles.BarRepresentation
---@field header chronicles.BarLevelRepresentation
---@field body chronicles.BarLevelRepresentation
---@field footer chronicles.BarLevelRepresentation

---@alias chronicles.Dashboard.TopProjectsArray chronicles.StringOrFalse[]

-- --------------------------------------------
-- Timeline Data
-- --------------------------------------------

---@class chronicles.Timeline.Data
---@field total_period_time integer
---@field segments? chronicles.Timeline.SegmentData[]
---@field max_segment_time integer
---@field does_include_curr_date boolean
---@field time_period_str string
---@field project_id_to_highlight table<string, string>
---@field sorted_project_ids string[]

---@class chronicles.Timeline.SegmentData
---@field day? string
---@field month? string
---@field year string
---@field date_abbr string
---@field total_segment_time integer
---@field project_shares chronicles.Timeline.SegmentData.ProjectShare[]

---@class chronicles.Timeline.SegmentData.ProjectShare
---@field project_id string
---@field share number (0-1]

---@class chronicles.Timeline.RowRepresentation
---@field realized_row string
---@field row_codepoint_count integer
---@field row_display_width integer
---@field row_bytes integer
---@field row_chars string[]
---@field row_char_display_widths integer[]
---@field row_char_bytes integer[]

---@class chronicles.Timeline.BarDistributionData
---@field bar_heights integer[]
---@field n_project_cells_by_share_by_segment integer[][]
---@field n_project_cells_by_share_by_segment_index integer[]
---@field bar_left_margin_cols integer[]

-- --------------------------------------------
-- Panel Data
-- --------------------------------------------

---@class chronicles.WindowDimensions
---@field width integer
---@field height integer
---@field row integer
---@field col integer

---@class chronicles.Highlight
---@field line integer
---@field col integer
---@field end_col integer
---@field hl_group string

---@alias chronicles.Panel.Actions table<string, fun(context: chronicles.Panel.Context)>

---@class chronicles.Panel.Data
---@field lines string[]
---@field highlights? chronicles.Highlight[]
---@field window_dimensions chronicles.WindowDimensions
---@field buf_name string
---@field window_title? string
---@field window_border? string[]
---@field actions? chronicles.Panel.Actions
---@field cursor_position? {row: integer, col: integer}

---@class chronicles.Panel.Context
---@field line_idx integer
---@field line_content string
---@field buf integer
---@field win integer

-- --------------------------------------------
-- Dev Chronicles Data
-- --------------------------------------------

---@class chronicles.ChroniclesData.ProjectData
---@field total_time integer
---@field by_year table<string, {by_month: table<string, number>, total_time: integer}>
---@field by_day table<string, number>
---@field first_worked integer
---@field last_worked integer
---@field last_worked_canonical integer
---@field last_cleaned integer
---@field tags_map? table<string, any>
---@field color? string

---@class chronicles.ChroniclesData
---@field global_time integer
---@field tracking_start integer
---@field last_data_write integer
---@field last_backup integer
---@field schema_version integer
---@field projects table<string, chronicles.ChroniclesData.ProjectData>

-- --------------------------------------------
-- Plugin Configuration Opts Types
-- --------------------------------------------

-- -- --------------------------------------------
-- -- Helper Types
-- -- --------------------------------------------

---@class chronicles.Options.Dashboard.DefaultVars
---@field bar_width integer
---@field bar_spacing integer
---@field bar_header_extends_by integer
---@field bar_footer_extends_by integer

-- -- --------------------------------------------
-- -- Dashboard & Timeline Common Opts
-- -- --------------------------------------------

---@class chronicles.Options.Common.Header.PeriodIndicator
---@field date_range boolean
---@field days_count boolean
---@field time_period_str? string
---@field time_period_str_singular? string

---@class chronicles.Options.Common.TotalTimeBase
---@field as_hours_max boolean
---@field as_hours_min boolean
---@field round_hours_ge_x? integer
---@field color? string

---@class chronicles.Options.Common.Header.TotalTime: chronicles.Options.Common.TotalTimeBase
---@field format_str string -- TODO: color not impl yet

---@class chronicles.Options.Common.Weighted
---@field weight? number

-- -- --------------------------------------------
-- -- Dashboard Opts
-- -- --------------------------------------------

---@class chronicles.Options.Dashboard.BarRepr: chronicles.Options.Common.Weighted
---@field header? string[]
---@field body string[]
---@field footer? string[]

---@class chronicles.Options.Dashboard.Header.TopProjects
---@field enable boolean
---@field extra_space_between_bars boolean
---@field wide_bars boolean
---@field super_extra_duper_wide_bars boolean
---@field min_top_projects_len_to_show integer

---@class chronicles.Options.Dashboard.Header.ProjectGlobalTime: chronicles.Options.Common.TotalTimeBase
---@field enable boolean
---@field show_only_if_differs boolean
---@field color_like_bars boolean

---@class chronicles.Options.Dashboard.Header
---@field period_indicator chronicles.Options.Common.Header.PeriodIndicator
---@field show_current_session_time boolean
---@field prettify boolean
---@field window_title string
---@field total_time chronicles.Options.Common.Header.TotalTime
---@field project_global_time chronicles.Options.Dashboard.Header.ProjectGlobalTime
---@field top_projects chronicles.Options.Dashboard.Header.TopProjects

---@class chronicles.Options.Dashboard.Sorting
---@field enable boolean
---@field sort_by_last_worked_not_total_time boolean
---@field ascending boolean

---@class chronicles.Options.Dashboard.Section.ProjectTotalTime: chronicles.Options.Common.TotalTimeBase
---@field color_like_bars boolean

---@class chronicles.Options.Dashboard.Section
---@field header chronicles.Options.Dashboard.Header
---@field sorting chronicles.Options.Dashboard.Sorting
---@field dynamic_bar_height_thresholds any?
---@field n_by_default integer
---@field random_bars_coloring boolean
---@field bars_coloring_follows_sorting_in_order boolean
---@field min_proj_time_to_display_proj integer
---@field window_height number
---@field window_width number
---@field window_border? string[]
---@field bar_reprs? chronicles.Options.Dashboard.BarRepr[]
---@field project_total_time chronicles.Options.Dashboard.Section.ProjectTotalTime

---@class chronicles.Options.Dashboard.Footer
---@field let_proj_names_extend_bars_by_one boolean

---@class chronicles.Options.Dashboard
---@field bar_width integer
---@field bar_header_extends_by integer
---@field bar_footer_extends_by integer
---@field bar_spacing integer
---@field bar_reprs chronicles.Options.Dashboard.BarRepr[]
---@field use_extra_default_dashboard_bar_reprs boolean
---@field dsh_days_today_force_precise_time boolean
---@field footer chronicles.Options.Dashboard.Footer
---@field extra_default_params_bar_reprs chronicles.Options.Dashboard.BarRepr[]
---@field dashboard_days chronicles.Options.Dashboard.Section
---@field dashboard_months chronicles.Options.Dashboard.Section
---@field dashboard_years chronicles.Options.Dashboard.Section
---@field dashboard_all chronicles.Options.Dashboard.Section

--- -- --------------------------------------------
--- -- Timeline Opts
--- -- --------------------------------------------

---@class chronicles.Options.Timeline.RowRepr: chronicles.Options.Common.Weighted
---@field body string

---@class chronicles.Options.Timeline
---@field row_reprs chronicles.Options.Timeline.RowRepr[]
---@field timeline_days chronicles.Options.Timeline.Section
---@field timeline_months chronicles.Options.Timeline.Section
---@field timeline_years chronicles.Options.Timeline.Section
---@field timeline_all chronicles.Options.Timeline.Section

---@class chronicles.Options.Timeline.Section
---@field bar_width integer
---@field bar_spacing integer
---@field row_reprs? chronicles.Options.Timeline.RowRepr[]
---@field n_by_default integer
---@field window_height integer
---@field window_width integer
---@field random_proj_coloring boolean
---@field header chronicles.Options.Timeline.Header
---@field segment_time_labels chronicles.Options.Timeline.Section.SegmentTimeLabels
---@field segment_numeric_labels chronicles.Options.Timeline.Section.SegmentNumericLabels
---@field segment_abbr_labels chronicles.Options.Timeline.Section.SegmentAbbrLabels

---@class chronicles.Options.Timeline.Header
---@field total_time chronicles.Options.Common.Header.TotalTime
---@field show_current_session_time boolean
---@field window_title string
---@field period_indicator chronicles.Options.Common.Header.PeriodIndicator
---@field project_prefix string

---@class chronicles.Options.Timeline.Section.SegmentLabelBase
---@field color? string
---@field color_like_top_segment_project boolean
---@field hide_when_empty boolean

---@class chronicles.Options.Timeline.Section.SegmentTimeLabels: chronicles.Options.Timeline.Section.SegmentLabelBase, chronicles.Options.Common.TotalTimeBase

---@class chronicles.Options.Timeline.Section.SegmentNumericLabels: chronicles.Options.Timeline.Section.SegmentLabelBase
---@field enable boolean

---@class chronicles.Options.Timeline.Section.SegmentAbbrLabels: chronicles.Options.Timeline.Section.SegmentLabelBase
---@field enable boolean
---@field locale? string: 'C' for English
---@field date_abbrs? string[]: timeline_days: 7 entries, Sunday first; timeline_months: 12 entries, January first

--- -- --------------------------------------------
--- -- Additional Top Level Opts
--- -- --------------------------------------------

---@class chronicles.Options.TrackDays
---@field enable boolean
---@field optimize_storage_for_x_days? integer

---@alias chronicles.Options.HighlightDefinitions.Definition { fg?: string, bg?: string, bold?: boolean, italic?: boolean, underline?: boolean }

---@class chronicles.Options.HighlightDefinitions
---@field DevChroniclesAccent chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesChartFloor chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesGrayedOut chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesLightGray chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesWindowBG? chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesWindowBorder chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesWindowTitle chronicles.Options.HighlightDefinitions.Definition
---@field DevChroniclesBackupColor chronicles.Options.HighlightDefinitions.Definition

---@class chronicles.Options.Backup
---@field interval? integer
---@field cleanup_interval? integer
---@field cleanup_n_to_keep integer

---@class chronicles.Options.StoragePaths
---@field data_file string
---@field log_file string
---@field backup_dir string

--- -- --------------------------------------------
--- -- Chronicles Options Base
--- -- --------------------------------------------

---@class chronicles.Options
---@field tracked_parent_dirs string[] List of parent dirs to track
---@field tracked_dirs string[] List of dir paths to track
---@field exclude_subdirs_relative string[] List of subdirs to exclude from tracked_parent_dirs subdirs
---@field exclude_dirs_absolute string[] List of absolute dirs to exclude (tracked_parent_dirs can have two different dirs that have two subdirs of the same name)
---@field sort_tracked_parent_dirs boolean If paths are not supplied from longest to shortest, then they need to be sorted like that
---@field differentiate_projects_by_folder_not_path boolean
---@field min_session_time integer Minimum session time in seconds
---@field track_days chronicles.Options.TrackDays
---@field extend_today_to_4am boolean
---@field dashboard chronicles.Options.Dashboard
---@field timeline chronicles.Options.Timeline
---@field project_list { show_help_hint: boolean }
---@field highlights chronicles.Options.HighlightDefinitions
---@field backup chronicles.Options.Backup
---@field storage_paths chronicles.Options.StoragePaths
---@field runtime_opts { for_dev_state_override?: chronicles.SessionState, parsed_exclude_subdirs_relative_map?: table<string, boolean>} -- exclude_subdirs_relative as a map
