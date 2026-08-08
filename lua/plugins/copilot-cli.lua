-- GitHub Copilot CLI in a side panel, replacing CopilotChat.nvim.
--
-- CopilotChat was an in-editor chat buffer talking to Copilot's backend through
-- copilot.lua's language server. This runs the real `copilot` CLI agent
-- (/opt/homebrew/bin/copilot) in a terminal instead, so it behaves like the
-- Claude Code panel: same snacks terminal, same side, same shape.
--
-- Inline Copilot completions are untouched -- those come from the separate
-- lazyvim.plugins.extras.ai.copilot extra, which is still enabled. Only the
-- copilot-chat extra was removed.
--
-- Removing copilot-chat also gave <leader>aa back to Claude's "Accept diff"
-- on its own, so the old override that moved CopilotChat's toggle to
-- <leader>at is gone with it.
--
-- Terminal-mode keys from lua/config/keymaps.lua apply here too: <C-q> leaves
-- terminal mode, <C-h/j/k/l> hops to another window.

local CMD = "copilot"

--- Toggle the Copilot CLI panel, rooted at the current project.
local function toggle()
  if vim.fn.executable(CMD) ~= 1 then
    vim.notify("`copilot` CLI not found on PATH", vim.log.levels.WARN, { title = "Copilot CLI" })
    return
  end
  Snacks.terminal.toggle(CMD, {
    cwd = LazyVim.root(),
    win = {
      position = "right",
      width = 0.38, -- matches the Claude Code panel
      wo = {
        winbar = "%#Title# Copilot CLI %*",
        number = false,
        relativenumber = false,
        signcolumn = "no",
        statuscolumn = "",
        cursorline = false,
      },
    },
  })
end

return {
  "folke/snacks.nvim",
  keys = {
    { "<leader>ap", toggle, desc = "Toggle Copilot CLI" },
  },
}
