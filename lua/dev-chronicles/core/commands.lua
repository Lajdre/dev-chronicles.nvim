local M = {}

---@param opts chronicles.Options
function M.setup_commands(opts)
  M._setup_the_command(opts)
  M._setup_autocmds(opts)
end

---@param opts chronicles.Options
function M._setup_the_command(opts)
  local api = require('dev-chronicles.api')
  local enums = require('dev-chronicles.core.enums')
  local notify = require('dev-chronicles.utils.notify')
  local storage_paths = require('dev-chronicles.utils.storage_paths')

  vim.api.nvim_create_user_command('DevChronicles', function(command_opts)
    local args = command_opts.fargs
    local first_arg = args[1]

    if #args == 0 then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, nil, opts)
    elseif first_arg == 'all' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.All, nil, opts)
    elseif first_arg == 'days' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Days,
        { start_offset = tonumber(args[2]), end_offset = tonumber(args[3]) },
        opts
      )
    elseif first_arg == 'months' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Months,
        { start_date = args[2], end_date = args[3] },
        opts
      )
    elseif first_arg == 'years' then
      api.panel(
        enums.PanelType.Dashboard,
        enums.PanelSubtype.Years,
        { start_date = args[2], end_date = args[3] },
        opts
      )
    elseif first_arg == 'today' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 0 }, opts)
    elseif first_arg == 'week' then
      api.panel(enums.PanelType.Dashboard, enums.PanelSubtype.Days, { start_offset = 6 }, opts)
    elseif first_arg == 'info' then
      local session_base, session_active = api.get_session_info(opts.extend_today_to_4am)
      notify.notify(
        vim.inspect(
          session_active and vim.tbl_extend('error', session_active, session_base)
            or vim.tbl_extend('error', session_base, { is_tracking = false })
        )
      )
    elseif first_arg == 'list' then
      require('dev-chronicles.panels.project_list').display_project_list(opts)
    elseif first_arg == 'abort' then
      api.abort_session()
      notify.notify('Session aborted')
    elseif first_arg == 'time' then
      require('dev-chronicles.panels.session_time').display_session_time()
    elseif first_arg == 'finish' then
      api.finish_session()
      notify.notify('Session finished')
    elseif first_arg == 'config' then
      if args[2] == 'default' then
        notify.notify(vim.inspect(require('dev-chronicles.config').get_default_opts()))
      else
        notify.notify(vim.inspect(opts))
      end
    elseif first_arg == 'clean' then
      api.clean_projects_day_data()
      notify.notify('Projects cleaned')
    elseif first_arg == 'logs' then
      if args[2] == 'clear' then
        require('dev-chronicles.panels.logs').clear_logs(storage_paths.get_log_file())
      else
        require('dev-chronicles.panels.logs').display_logs(storage_paths.get_log_file())
      end
    elseif first_arg == 'validate' then
      require('dev-chronicles.utils').validate_data({ data_path = opts.data_file })
    elseif first_arg == 'timeline' then
      if args[2] == 'months' then
        api.panel(
          enums.PanelType.Timeline,
          enums.PanelSubtype.Months,
          { start_date = args[3], end_date = args[4] },
          opts
        )
      elseif args[2] == 'years' then
        api.panel(
          enums.PanelType.Timeline,
          enums.PanelSubtype.Years,
          { start_date = args[3], end_date = args[4] },
          opts
        )
      elseif args[2] == 'all' then
        api.panel(enums.PanelType.Timeline, enums.PanelSubtype.All, nil, opts)
      else
        api.panel(
          enums.PanelType.Timeline,
          enums.PanelSubtype.Days,
          { start_offset = tonumber(args[2]), end_offset = tonumber(args[3]) },
          opts
        )
      end
    elseif first_arg == 'pause' then
      require('dev-chronicles.panels.paused').pause(opts.extend_today_to_4am)
    else
      notify.notify(
        'Usage: :DevChronicles [all | days [start_offset [end_offset]] |'
          .. 'months [start_date [end_date]] | today | week | info | abort | clean | logs | validate | pause]'
      )
    end
  end, {
    nargs = '*',
    complete = function(_arg_lead, cmd_line, _cursor_pos)
      local split = vim.split(cmd_line, '%s+')
      local n_splits = #split
      if n_splits == 2 then
        return {
          'all',
          'days',
          'months',
          'info',
          'abort',
          'time',
          'config',
          'clean',
          'logs',
          'validate',
          'pause',
        }
      elseif n_splits == 3 then
        if split[2] == 'days' then
          return { '29' }
        elseif split[2] == 'months' then
          return { 'MM.YYYY' }
        elseif split[2] == 'years' then
          return { 'YYYY' }
        elseif split[2] == 'config' then
          return { 'default' }
        elseif split[2] == 'logs' then
          return { 'clear' }
        end
      end
    end,
  })
end

---@param opts chronicles.Options
function M._setup_autocmds(opts)
  local group = vim.api.nvim_create_augroup('DevChronicles', { clear = true })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      require('dev-chronicles.core.state').start_session(opts)
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      require('dev-chronicles.core.session_ops').end_session(
        require('dev-chronicles.utils.storage_paths').get_data_file(),
        opts.track_days,
        opts.min_session_time,
        opts.extend_today_to_4am,
        opts.backup
      )
    end,
  })
end

return M
