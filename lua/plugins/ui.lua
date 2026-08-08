-- Visual polish that isn't colour: start screen, tab bar, floats, motion.
return {
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[

      ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗
      ████╗  ██║ ██╔════╝ ██╔═══██╗ ██║   ██║ ██║ ████╗ ████║
      ██╔██╗ ██║ █████╗   ██║   ██║ ██║   ██║ ██║ ██╔████╔██║
      ██║╚██╗██║ ██╔══╝   ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║
      ██║ ╚████║ ███████╗ ╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║
      ╚═╝  ╚═══╝ ╚══════╝  ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝

]],
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          -- Which project you are about to open, before you open anything.
          -- Icons are \u{...} escapes (Nerd Font private use area) so they
          -- survive tools that strip unknown codepoints -- see lualine.lua.
          {
            pane = 2,
            icon = "\u{f1da} ", -- history
            title = "Recent Files",
            section = "recent_files",
            indent = 2,
            padding = 1,
          },
          {
            pane = 2,
            icon = "\u{f07c} ", -- folder-open
            title = "Projects",
            section = "projects",
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
