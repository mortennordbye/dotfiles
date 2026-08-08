-- Colorscheme tuning. Single owner of tokyonight's `opts`.
--
-- This file replaces the old window-separator.lua: lazy.nvim merges `opts`
-- tables across specs, but `on_highlights` is a function, so two specs each
-- defining one meant the later-loaded file silently won. Keeping every
-- tokyonight override here means there is exactly one on_highlights.
--
-- LazyVim picks the `moon` style. Ghostty is themed to match (TokyoNight Moon)
-- so the terminal chrome and the editor background are the same colour.
return {
  "folke/tokyonight.nvim",
  opts = {
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
      hl.CursorLineNr = { fg = c.orange, bold = true }
    end,
  },
}
