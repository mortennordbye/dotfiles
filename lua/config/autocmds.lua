-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- (WinSeparator used to be forced here with a hardcoded #7aa2f7. It now lives in
-- tokyonight's on_highlights -- see lua/plugins/colorscheme.lua -- so the colour
-- follows the palette instead of fighting it. This autocmd ran after the theme
-- and overrode it, which also defeated dim_inactive on the separator.)

-- Show the cursorline only in the focused window, so the highlighted row also
-- marks which split you are in. Limited to file buffers: the explorer's
-- cursorline is its selection and should stay visible when unfocused, and
-- terminals and the activity bar turn it off themselves.
local cursorline_group = vim.api.nvim_create_augroup("cursorline_focus", { clear = true })
vim.api.nvim_create_autocmd("WinLeave", {
  group = cursorline_group,
  callback = function()
    if vim.bo.buftype == "" and vim.wo.cursorline then
      vim.w.cursorline_hidden = true
      vim.wo.cursorline = false
    end
  end,
})
vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
  group = cursorline_group,
  callback = function()
    if vim.w.cursorline_hidden then
      vim.w.cursorline_hidden = nil
      vim.wo.cursorline = true
    end
  end,
})

-- Label editor windows with their filename in the winbar, like the Claude Code
-- panel's label. WinBar/WinBarNC (lua/plugins/colorscheme.lua) colour it bright
-- in the focused window and grey elsewhere, which is the clearest "you are
-- here" cue. Floats, terminals and the explorer are left alone; the flag makes
-- sure only winbars set here are ever replaced or cleared.
local function label_window(win)
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local dashboard = vim.bo[buf].filetype == "snacks_dashboard"
  local ours = vim.w[win].editor_winbar
  local editor = vim.bo[buf].buftype == "" and vim.bo[buf].filetype ~= "activitybar" and not vim.w[win].snacks_layout
  if not (editor or dashboard) then
    if ours then
      vim.wo[win].winbar = ""
      vim.w[win].editor_winbar = nil
    end
    return
  end
  if vim.wo[win].winbar ~= "" and not ours then
    return
  end
  vim.wo[win].winbar = dashboard and " Dashboard " or " %t%m "
  vim.w[win].editor_winbar = true
end
vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "TermOpen" }, {
  group = vim.api.nvim_create_augroup("editor_winbar", { clear = true }),
  callback = function(ev)
    for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
      label_window(win)
    end
  end,
})
for _, win in ipairs(vim.api.nvim_list_wins()) do
  label_window(win) -- windows already open before VeryLazy loaded this file
end

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

-- LazyVim evens out the splits on VimResized with `tabdo wincmd =`. In a
-- resize from outside (AeroSpace re-tiling, a monitor change) that call left a
-- second window on the Claude panel, made inside the autocmd so no WinNew
-- fired for it (see layout_stray.log entries from 2026-10-19). Same job on
-- the current tab only, without tabdo.
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_resize_splits")
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("resize_splits", { clear = true }),
  callback = function()
    vim.cmd("wincmd =")
  end,
})

-- Keep editor, sidebars and terminal panels in their places; see lua/config/layout.lua.
require("config.layout").setup()

-- VSCode-style activity bar down the left edge; see lua/config/activitybar.lua.
require("config.activitybar").setup()
