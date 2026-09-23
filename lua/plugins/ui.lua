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

          -- `p` and `d` are the two "where do I start?" entries: p picks a git
          -- repo, d picks any folder under ~/Documents. "Recent Files" gets no
          -- shortcut because that section below already has its own 1..n keys.
          -- Icons as \u{...} escapes, same reason as everywhere else in this
          -- file: literal Nerd Font glyphs get stripped to bare spaces.
          -- stylua: ignore
          keys = {
            { icon = "\u{f07b} ",  key = "p", desc = "Open Project",     action = function() require("config.pickers").projects() end },
            { icon = "\u{f07c} ",  key = "d", desc = "Open Folder",      action = function() require("config.pickers").folders() end },
            { icon = "\u{f002} ",  key = "f", desc = "Find File",       action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "\u{f15c} ",  key = "g", desc = "Find Text",       action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "\u{f15b} ",  key = "n", desc = "New File",        action = ":ene | startinsert" },
            { icon = "\u{f0e2} ",  key = "s", desc = "Restore Session", section = "session" },
            { icon = "\u{f013} ",  key = "c", desc = "Config",          action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "\u{f04b2} ", key = "l", desc = "Lazy",            action = ":Lazy" },
            { icon = "\u{f011} ",  key = "q", desc = "Quit",            action = ":qa" },
          },
        },

        -- Recent files and projects: name first, then the folder it lives in,
        -- dimmed, like VSCode's Open Recent. The stock format prints the full
        -- path and, when it doesn't fit, shortens every folder to one letter
        -- (~/D/O/s/d/a/l/u/main.bicep), which hides both the name and where
        -- it is. Here only the folder is cut, from the left.
        formats = {
          file = function(item, ctx)
            local path = vim.fn.fnamemodify(item.file, ":~")
            local name = vim.fn.fnamemodify(path, ":t")
            local dir = vim.fn.fnamemodify(path, ":h")
            local room = (ctx.width or 60) - vim.api.nvim_strwidth(name) - 2
            if vim.api.nvim_strwidth(dir) > room then
              dir = room > 1 and "…" .. vim.fn.strcharpart(dir, vim.fn.strchars(dir) - room + 1) or ""
            end
            return { { name, hl = "file" }, { "  " .. dir, hl = "dir" } }
          end,
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
            -- oldfiles also remembers folders opened with `nvim <dir>`
            filter = function(file)
              return vim.fn.isdirectory(file) == 0
            end,
            limit = 5,
            indent = 2,
            padding = 1,
          },
          {
            icon = "\u{f07c} ", -- folder-open
            title = "Projects",
            section = "projects",
            -- Real repositories under the dev roots, newest first. Without
            -- this the section walks recent files and resolves git roots,
            -- so it only ever listed the two repos with recent edits.
            dirs = function()
              return require("config.pickers").repos()
            end,
            limit = 5,
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
