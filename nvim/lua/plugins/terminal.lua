-- Terminal window behaviour (snacks.nvim owns the terminal that claudecode.nvim
-- runs Claude in, via the lazyvim.plugins.extras.ai.claudecode extra).
-- Keys are also documented by hand in lua/config/cheatsheet_data.lua -- see README.md.
-- Fast terminal toggle: <A-t>.
--
-- LazyVim's stock toggle is <C-/>, which on a Norwegian layout means
-- Ctrl+Shift+7 -- a three-finger chord for the thing you want instantly.
-- <A-t> is a plain letter, so it costs the same on any layout. (Ghostty is
-- configured with macos-option-as-alt, so Option reaches Neovim as Alt.)
--
-- Opens at the git root rather than the buffer's directory, so `git` commands
-- act on the repo you are actually in. snacks keys the terminal instance on
-- cmd+cwd, so the first <A-t> spawns a shell and every later one just shows
-- and hides that same one -- no reopening cost, and scrollback survives.
--
-- <C-/> is left alone; this is an addition, not a replacement.
local function toggle_terminal()
  Snacks.terminal.toggle(nil, {
    cwd = LazyVim.root.git(),
    win = { position = "bottom", height = 0.35 },
  })
end

return {
  "folke/snacks.nvim",
  keys = {
    { "<A-t>", toggle_terminal, desc = "Terminal (git root)", mode = { "n", "t" } },
  },
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
