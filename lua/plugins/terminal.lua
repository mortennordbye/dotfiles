-- Terminal window behaviour (snacks.nvim owns the terminal that claudecode.nvim
-- runs Claude in, via the lazyvim.plugins.extras.ai.claudecode extra).
-- Keys are also documented by hand in a cheatsheet outside this repo -- see README.md.
return {
  "folke/snacks.nvim",
  opts = {
    styles = {
      terminal = {
        keys = {
          -- Disable snacks' "double escape to normal mode".
          --
          -- Its implementation is an expr mapping that, on the FIRST <esc>, starts
          -- a 200ms timer and forwards that <esc> to the running program; a second
          -- <esc> inside the window then does stopinsert. In a Claude Code terminal
          -- that means leaving terminal mode always fires Claude's interrupt first,
          -- and Claude never sees a clean Esc Esc for its own rewind / edit-previous
          -- -message. See snacks.nvim/lua/snacks/terminal.lua (term_normal).
          --
          -- With this off, <esc> is passed straight through untouched and we use
          -- <C-q> to leave terminal mode instead (mapped in lua/config/keymaps.lua).
          term_normal = false,
        },
      },
    },
  },
}
