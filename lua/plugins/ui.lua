-- Visual polish that isn't colour: start screen, tab bar, floats, motion.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        -- ANSI Shadow lettering. Every line is exactly 50 display cells wide;
        -- the ╔╗╚╝ shadow glyphs only line up if the letters are NOT separated
        -- by extra spaces, which is what made the first attempt look doubled.
        preset = {
          header = table.concat({
            "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
            "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
            "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
            "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
            "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
            "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
          }, "\n"),

          -- "Recent Files" and "Projects" are dropped from the shortcut list:
          -- both appear below as real sections with their own 1..n keys, and
          -- listing them twice was the main source of clutter.
          -- Icons as \u{...} escapes, same reason as everywhere else in this
          -- file: literal Nerd Font glyphs get stripped to bare spaces.
          -- stylua: ignore
          keys = {
            { icon = "\u{f002} ",  key = "f", desc = "Find File",       action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "\u{f15c} ",  key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "\u{f15b} ",  key = "n", desc = "New File",        action = ":ene | startinsert" },
            { icon = "\u{f0e2} ",  key = "s", desc = "Restore Session", section = "session" },
            { icon = "\u{f013} ",  key = "c", desc = "Config",          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "\u{f04b2} ", key = "l", desc = "Lazy",            action = ":Lazy" },
            { icon = "\u{f011} ",  key = "q", desc = "Quit",            action = ":qa" },
          },
        },

        -- Single column. `pane = 2` needs roughly 2x the section width to
        -- render side by side; below that snacks silently stacks the panes,
        -- which is why the two-pane version came out as one long list.
        sections = {
          { section = "header", padding = 1 },
          { section = "keys", padding = 1 },
          -- Icons are \u{...} escapes (Nerd Font private use area) so they
          -- survive tools that strip unknown codepoints -- see lualine.lua.
          {
            icon = "\u{f1da} ", -- history
            title = "Recent Files",
            section = "recent_files",
            limit = 5,
            indent = 2,
            padding = 1,
          },
          {
            icon = "\u{f07c} ", -- folder-open
            title = "Projects",
            section = "projects",
            limit = 3,
            indent = 2,
            padding = 1,
          },
          { section = "startup" },
        },
      },

      -- Indent guides: keep the scope highlight, slow the animation down a
      -- touch so it reads as a sweep rather than a flicker.
      indent = {
        animate = { duration = { step = 15, total = 300 } },
      },
      scroll = {
        animate = { duration = { step = 12, total = 220 } },
      },
    },
  },

  -- Tab bar: angled separators and a thicker active-buffer indicator, so the
  -- focused buffer is obvious at a glance.
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = "slant",
        indicator = { style = "underline" },
        show_buffer_close_icons = false,
      },
    },
  },

  -- Bordered LSP hover/signature popups, matching vim.o.winborder.
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
}
