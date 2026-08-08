-- Claude Code panel (coder/claudecode.nvim, from lazyvim.plugins.extras.ai.claudecode).
--
-- This file replaces the old lua/plugins/claude.lua, which pulled in a SECOND
-- integration (greggh/claude-code.nvim) on <leader>cc. Two problems with that:
--
--   1. Both plugins were installed and each could start its own Claude session.
--   2. <leader>cc is LazyVim's "Run Codelens", which is a buffer-local LSP
--      mapping and therefore wins wherever a language server is attached. So
--      <leader>cc ran codelens, not Claude, in exactly the files you edit most.
--
-- The extra's keys are the <leader>a* group: ac toggle, af focus, ar resume,
-- aC continue, ab add buffer, as send selection, aa/ad accept/deny diff.
--
-- Terminal behaviour is snacks.nvim's; see lua/plugins/terminal.lua for why
-- snacks' double-<esc> mapping is turned off (it stole Claude's interrupt).
return {
  "coder/claudecode.nvim",
  opts = {
    terminal = {
      split_side = "right",

      -- 0.30 is the plugin default. Claude's prose and code blocks wrap hard at
      -- that width on a wide display; the extra few percent removes most of the
      -- reflow without meaningfully squeezing the editor.
      split_width_percentage = 0.38,

      -- While a diff is open the diff needs the room more than the transcript
      -- does, so give the terminal less and hand the difference to the diff.
      -- Restored automatically when the diff closes.
      diff_split_width_percentage = 0.28,

      snacks_win_opts = {
        wo = {
          -- Name the pane. Without this it is an unlabelled terminal sitting
          -- next to the editor, which is ambiguous once there is more than one
          -- split open.
          winbar = "%#Title# Claude Code %*",
          number = false,
          relativenumber = false,
          signcolumn = "no",
          statuscolumn = "",
          cursorline = false,
        },
      },
    },
  },
}
