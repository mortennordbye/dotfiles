-- Make the divider between split windows clearly visible.
-- Done inside tokyonight's own highlight step so nothing overrides it later.
-- (The heavy line characters themselves are set in lua/config/options.lua.)
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      on_highlights = function(hl, c)
        hl.WinSeparator = { fg = c.blue, bold = true }
      end,
    },
  },
}
