-- Colorscheme tuning. Single owner of tokyonight's `opts`.
--
-- This file replaces the old window-separator.lua: lazy.nvim merges `opts`
-- tables across specs, but `on_highlights` is a function, so two specs each
-- defining one meant the later-loaded file silently won. Keeping every
-- tokyonight override here means there is exactly one on_highlights.
--
-- The palette is a custom "balanced" style rather than one of tokyonight's own.
-- Moon's comments sat at 3.1:1 contrast against the background, which is below
-- the 4.5:1 readability floor; this keeps a dark slate ground but lifts text to
-- 12.7:1, comments to 5.4:1 and every syntax accent to 7:1 or better.
--
-- It is registered as a tokyonight style (not patched in via on_colors) because
-- on_colors runs after tokyonight derives the float, sidebar, diff and terminal
-- colours from the base palette, so swapping `bg` there would leave those on the
-- old values. As a style, everything is derived from these colours instead.
--
-- Ghostty's background and foreground are set to match in ~/.config/ghostty/config.
local balanced = {
  bg = "#1b1e24",
  bg_dark = "#16181d",
  bg_dark1 = "#121418",
  bg_highlight = "#242831",
  fg = "#dce1e8",
  fg_dark = "#aab2bf",
  fg_gutter = "#6b7280",
  comment = "#8a93a3",
  dark3 = "#5c6370",
  dark5 = "#7d8594",
  terminal_black = "#4b5263",
  blue = "#7cb7ff", -- functions
  blue0 = "#3a5a8c", -- visual selection, search
  blue1 = "#79c8f2", -- types
  blue2 = "#4fc1e9",
  blue5 = "#9ccfe0", -- operators
  blue6 = "#b4f0f8",
  blue7 = "#2c3e5c", -- diff change
  cyan = "#8fd8f0",
  magenta = "#c4a7ff", -- keywords
  magenta2 = "#ff5fa2",
  purple = "#c4a7ff", -- keywords
  orange = "#f5a97f", -- numbers, constants
  yellow = "#e8c77d", -- parameters
  green = "#a8d98a", -- strings
  green1 = "#7fd4c9", -- properties
  green2 = "#5fb3a8",
  teal = "#7fd4c9",
  red = "#ff8b92", -- builtins like `vim`
  red1 = "#e0606a",
  git = { add = "#8ccf7e", change = "#7cb7ff", delete = "#e8727c" },
}

return {
  "folke/tokyonight.nvim",
  config = function(_, opts)
    require("tokyonight.colors").styles.balanced = function()
      return vim.deepcopy(balanced)
    end
    require("tokyonight").setup(opts)
  end,
  opts = {
    style = "balanced",
    -- Fade windows that don't have focus. With an editor split next to the
    -- Claude Code terminal this is the clearest possible "you are typing here".
    dim_inactive = true,
    -- Bold section headers in the statusline.
    lualine_bold = true,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      -- Give the file explorer and floating windows their own slightly
      -- recessed background, so panels read as panels rather than as more
      -- editor area that happens to contain a tree.
      sidebars = "dark",
      floats = "dark",
    },
    on_highlights = function(hl, c)
      -- Divider between split windows. Heavy line characters come from
      -- fillchars in lua/config/options.lua.
      hl.WinSeparator = { fg = c.blue, bold = true }

      -- Rounded float borders (vim.o.winborder in options.lua) only look
      -- deliberate if the border is tinted rather than the default dim grey.
      hl.FloatBorder = { fg = c.blue, bg = c.bg_float }
      hl.FloatTitle = { fg = c.blue, bg = c.bg_float, bold = true }

      -- Snacks picker: lift the prompt and selection out of the background.
      hl.SnacksPickerBorder = { fg = c.blue, bg = c.bg_float }
      hl.SnacksPickerPrompt = { fg = c.blue, bg = c.bg_float, bold = true }

      -- The active line number should be readable, not just "slightly less dim".
      hl.CursorLineNr = { fg = c.yellow, bold = true }
    end,
  },
}
