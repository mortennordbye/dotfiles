-- Google's Antigravity CLI (`agy`, in ~/.local/bin) in a side panel, the same
-- shape as the Claude Code and Copilot CLI panels (lua/plugins/copilot-cli.lua).
--
-- Terminal-mode keys from lua/config/keymaps.lua apply here too: <C-q> leaves
-- terminal mode, <C-h/j/k/l> hops to another window.

local CMD = "agy"

--- Toggle the Antigravity CLI panel, rooted at the current project.
local function toggle()
  if vim.fn.executable(CMD) ~= 1 then
    vim.notify("`agy` (Antigravity CLI) not found on PATH", vim.log.levels.WARN, { title = "Antigravity CLI" })
    return
  end
  Snacks.terminal.toggle(CMD, {
    cwd = LazyVim.root(),
    win = {
      position = "right",
      width = 0.38, -- matches the Claude Code panel
      wo = {
        winbar = "%#Title# Antigravity CLI %*",
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
    { "<leader>ag", toggle, desc = "Toggle Antigravity CLI" },
  },
}
