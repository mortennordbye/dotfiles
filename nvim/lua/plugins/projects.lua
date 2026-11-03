-- Project and folder navigation.
--
-- Two different needs, two pickers (both defined in lua/config/pickers.lua):
--   <leader>fp  Projects -- git repos only, resolved by root pattern (.git,
--               package.json, Makefile, ...).
--   <leader>fD  Folders  -- any directory under ~/Documents, git or not, for
--               the Obsidian/latex/Scripts style folders that have no repo.
--
-- Both are also reachable from the start screen as `p` and `d`.
local pickers = require("config.pickers")

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            dev = pickers.dev_roots,
            -- Do not also scrape project roots out of recent-file history:
            -- with dev roots set correctly that only adds duplicates and
            -- one-off directories you opened a single file in.
            recent = false,
          },
        },
      },
    },
    keys = {
      { "<leader>fD", pickers.folders, desc = "Folders (~/Documents)" },
    },
  },
}
