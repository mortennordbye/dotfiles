-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Brighten the divider between split windows (e.g. editor vs. Claude Code panel)
-- so the boundary is obvious. Re-applied whenever the colorscheme loads.
local function set_win_separator()
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#7aa2f7", bold = true })
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("clear_win_separator", { clear = true }),
  callback = set_win_separator,
})
set_win_separator()

-- Keep the Claude Code terminal OUT of the top bufferline / tab bar.
-- It has its own panel; listing it as a buffer let it show up as a duplicate
-- tab (and get displayed in a second window). Unlisting fixes that.
vim.api.nvim_create_autocmd("TermOpen", {
  group = vim.api.nvim_create_augroup("unlist_claude_code", { clear = true }),
  callback = function(ev)
    local name = vim.api.nvim_buf_get_name(ev.buf)
    if name:find("claude%-code") or name:find("claude") then
      vim.bo[ev.buf].buflisted = false
    end
  end,
})

-- Auto-reload files changed on disk (e.g. by Claude Code) even while nvim keeps
-- focus. LazyVim already checks on FocusGained/BufEnter; this adds the idle case
-- (CursorHold) and notifies when a buffer is reloaded, so nothing looks stale.
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("auto_reload_disk", { clear = true }),
  callback = function()
    if vim.fn.getcmdwintype() == "" then
      vim.cmd("checktime")
    end
  end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = vim.api.nvim_create_augroup("auto_reload_notify", { clear = true }),
  callback = function()
    vim.notify("File changed on disk — buffer reloaded", vim.log.levels.INFO)
  end,
})
