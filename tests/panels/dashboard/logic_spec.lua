local dashboard_logic = require('dev-chronicles.panels.dashboard.logic')

describe('panels.dashboard.logic', function()
  describe('construct_bar_representation', function()
    it('works when receiving header, body, and footer specs', function()
      local input = {
        { ' ╔══▣◎▣══╗ ' },
        { '║       ║' },
        { ' ╚══▣◎▣══╝ ' },
      }
      local got = dashboard_logic.construct_bar_representation(input, 9, 1, 1)

      assert.are.same({
        header = {
          realized_rows = { ' ╔══▣◎▣══╗ ' },
          row_codepoint_counts = { 11 },
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
        },
        body = {
          realized_rows = { '║       ║' },
          row_codepoint_counts = { 9 },
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
        },
        footer = {
          realized_rows = { ' ╚══▣◎▣══╝ ' },
          row_codepoint_counts = { 11 },
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
        },
      }, got)
    end)

    it(
      'works when receiving only the body spec. All row width equal bar_width when bar_header_extends_by and bar_footer_extends_by equal 0',
      function()
        local input = { {}, { '▉' }, {} }
        local got = dashboard_logic.construct_bar_representation(input, 9, 0, 0)

        assert.are.same({
          header = {
            realized_rows = {},
            row_codepoint_counts = {},
            char_display_widths = {},
          },
          body = {
            realized_rows = { '▉▉▉▉▉▉▉▉▉' },
            row_codepoint_counts = { 9 },
            char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
          },
          footer = {
            realized_rows = {},
            row_codepoint_counts = {},
            char_display_widths = {},
          },
        }, got)
      end
    )

    it(
      'works when receiving only the body spec. All row width equal bar_width when bar_header_extends_by and bar_footer_extends_by equal 1',
      function()
        local input = { {}, { '▉' }, {} }
        local got = dashboard_logic.construct_bar_representation(input, 9, 1, 1)

        assert.are.same({
          header = {
            realized_rows = {},
            row_codepoint_counts = {},
            char_display_widths = {},
          },
          body = {
            realized_rows = { '▉▉▉▉▉▉▉▉▉' },
            row_codepoint_counts = { 9 },
            char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
          },
          footer = {
            realized_rows = {},
            row_codepoint_counts = {},
            char_display_widths = {},
          },
        }, got)
      end
    )

    it('works for multiple-level body spec with a header', function()
      local input = {
        { ' ▼ ' },
        {
          '███████',
          ' █████ ',
          '  ███  ',
          '  ███  ',
          ' █████ ',
          '███████',
        },
        {},
      }
      local got = dashboard_logic.construct_bar_representation(input, 9, 1, 0)

      assert.are.same({
        header = {
          realized_rows = { ' ▼ ' },
          row_codepoint_counts = { 11 },
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
        },
        body = {
          realized_rows = {
            '███████',
            ' █████ ',
            '  ███  ',
            '  ███  ',
            ' █████ ',
            '███████',
          },
          row_codepoint_counts = { 9, 9, 9, 9, 9, 9 },
          char_display_widths = {
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
            { 1, 1, 1, 1, 1, 1, 1, 1, 1 },
          },
        },
        footer = {
          realized_rows = {},
          row_codepoint_counts = {},
          char_display_widths = {},
        },
      }, got)
    end)

    it('falls back to "@" representation when body level is empty', function()
      local input = { { 'head' }, {}, { 'foot' } }

      local got = dashboard_logic.construct_bar_representation(input, 9, 0, 0)

      assert.are.same({
        body = {
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
          realized_rows = { '@@@@@@@@@' },
          row_codepoint_counts = { 9 },
        },
        footer = {
          char_display_widths = {},
          realized_rows = {},
          row_codepoint_counts = {},
        },
        header = {
          char_display_widths = {},
          realized_rows = {},
          row_codepoint_counts = {},
        },
      }, got)
    end)

    it('falls back to "@" when row width does not divide evenly', function()
      local input = { { 'abc' }, { 'xy' }, { 'z' } }

      local got = dashboard_logic.construct_bar_representation(input, 9, 0, 0)

      assert.are.same({
        body = {
          char_display_widths = { { 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
          realized_rows = { '@@@@@@@@@' },
          row_codepoint_counts = { 9 },
        },
        footer = {
          char_display_widths = {},
          realized_rows = {},
          row_codepoint_counts = {},
        },
        header = {
          char_display_widths = {},
          realized_rows = {},
          row_codepoint_counts = {},
        },
      }, got)
    end)
  end)
end)
