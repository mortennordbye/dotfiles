-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Keys are also documented by hand in lua/config/cheatsheet_data.lua -- see README.md.

-- Simple, no-prefix window splitting (avoids <C-w> and the awkward | key).
-- Move between windows with Ctrl+h/j/k/l (LazyVim default).
local map = vim.keymap.set
map("n", "<leader>wv", "<cmd>vsplit<cr>", { desc = "Split window vertically (side by side)" })
map("n", "<leader>wh", "<cmd>split<cr>", { desc = "Split window horizontally (stacked)" })
map("n", "<leader>wq", "<cmd>close<cr>", { desc = "Close this window" })

-- Let Ctrl+h/j/k/l move OUT of a terminal (e.g. the Claude Code panel).
-- Without these, terminal mode swallows the keys and you get stuck inside.
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Go to left window" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Go to lower window" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Go to upper window" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Go to right window" })

-- Resize with Ctrl+Shift+arrows or Ctrl+Shift+h/j/k/l (Ctrl+h/j/k/l moves
-- between windows, adding Shift resizes). LazyVim's Ctrl+arrows never arrive:
-- macOS keeps them for Mission Control and switching Spaces. Mapped in
-- terminal mode too, so the Claude panel resizes without leaving it first.
-- Width steps are larger because columns are much narrower than rows.
-- Ctrl+Shift+letter only reaches nvim as its own key because Ghostty speaks
-- the kitty keyboard protocol; in a plainer terminal it arrives as Ctrl+letter.
for _, r in ipairs({
  { "<C-S-Up>", "<C-S-k>", "resize +2", "Taller window" },
  { "<C-S-Down>", "<C-S-j>", "resize -2", "Shorter window" },
  { "<C-S-Left>", "<C-S-h>", "vertical resize -4", "Narrower window" },
  { "<C-S-Right>", "<C-S-l>", "vertical resize +4", "Wider window" },
}) do
  map({ "n", "t" }, r[1], "<cmd>" .. r[3] .. "<cr>", { desc = r[4] })
  map({ "n", "t" }, r[2], "<cmd>" .. r[3] .. "<cr>", { desc = r[4] })
end

-- Leave terminal mode. Deliberately NOT <Esc> or <Esc><Esc>: Claude Code uses Esc
-- as its interrupt and Esc Esc for rewind, so any mapping there either steals those
-- keys or delays them by 'timeoutlen'. <C-q> is unused by Claude and by nvim in
-- terminal mode, and q needs no modifier on a Norwegian layout.
-- (snacks' own double-esc mapping is disabled in lua/plugins/terminal.lua.)
map("t", "<C-q>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- The same two keys while typing in a file, so leaving a typing mode works the
-- same everywhere: <C-q> stops typing, <C-h/j/k/l> stops typing AND moves.
-- Terminals re-enter terminal mode by themselves when you come back (snacks'
-- auto_insert); a file comes back in normal mode.
-- The insert-mode <C-k> signature help from LazyVim's LSP keys and blink.cmp is
-- turned off in lua/plugins/navigation.lua so it can't shadow this; gK still
-- shows it from normal mode.
map("i", "<C-q>", "<Esc>", { desc = "Exit insert mode" })
map("i", "<C-h>", "<Esc><C-w>h", { desc = "Go to left window" })
map("i", "<C-j>", "<Esc><C-w>j", { desc = "Go to lower window" })
map("i", "<C-k>", "<Esc><C-w>k", { desc = "Go to upper window" })
map("i", "<C-l>", "<Esc><C-w>l", { desc = "Go to right window" })

-- <C-w> is deliberately NOT mapped in terminal mode. It used to start a window
-- command from inside a terminal, but <C-w> is also word-delete at Claude's
-- prompt and in the shell: press it out of habit, keep typing, and the next
-- letter ran as a window command. "s" split the Claude panel into two stacked
-- copies, "v" side by side, and claudecode then lost track of which window
-- was its own. For window commands in a terminal, press <C-q> first.

-- Reload files from disk (handy when edited externally, e.g. by Claude Code,
-- while open here). <leader>br = safe reload of any changed buffers;
-- <leader>bR = force-reload current buffer (discards local unsaved changes).
map("n", "<leader>br", "<cmd>checktime<cr>", { desc = "Reload changed files from disk" })
map("n", "<leader>bR", "<cmd>edit!<cr>", { desc = "Force reload buffer (discard changes)" })

-- Show / hide the VSCode-style activity bar (lua/config/activitybar.lua).
map("n", "<leader>uA", function()
  require("config.activitybar").toggle()
end, { desc = "Toggle Activity Bar" })
-- Lock Layout (lua/config/layout.lua). Mapped here, not in its setup(): that
-- runs from autocmds.lua, which LazyVim loads before snacks when nvim starts
-- with a file or folder argument, so the Snacks global isn't there yet.
Snacks.toggle({
  name = "Lock Layout",
  get = function()
    return require("config.layout").locked
  end,
  set = function(on)
    require("config.layout").set(on)
  end,
}):map("<leader>uP")
map("n", "<leader>uX", function()
  require("config.activitybar").choose_icons()
end, { desc = "Choose Activity Bar icons" })

-- Claude hub (lua/config/claude_hub.lua): every Claude session on this machine,
-- from any nvim, with its live chat; reply or approve without switching windows.
map("n", "<leader>ah", function()
  require("config.claude_hub").toggle()
end, { desc = "Claude hub (all sessions)" })

-- Keybinding cheatsheet (lua/config/cheatsheet.lua; content in cheatsheet_data.lua).
map("n", "<leader>h", function()
  require("config.cheatsheet").open()
end, { desc = "Cheatsheet" })

-- Restart nvim (0.12's :restart) and come back to the same files and splits,
-- e.g. after changing this config. Terminals don't survive a restart, so the
-- Claude / Copilot panels close; reopen them and run `claude --continue`.
-- Windows that can't be restored (terminals, pickers, the activity bar) are
-- closed first, or the session would bring them back as empty splits.
map("n", "<leader>qr", function()
  local modified = vim.tbl_filter(function(b)
    return vim.bo[b].modified and vim.bo[b].buftype == ""
  end, vim.api.nvim_list_bufs())
  if #modified > 0 then
    local choice = vim.fn.confirm("Save changes before restarting?", "&Save all\n&Discard\n&Cancel", 1)
    if choice == 1 then
      vim.cmd("wall")
    elseif choice ~= 2 then
      return
    end
  end
  require("config.activitybar").close()
  for _, p in ipairs(Snacks.picker.get()) do
    p:close()
  end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype ~= "" or vim.api.nvim_win_get_config(w).relative ~= "" then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  local session = vim.fn.stdpath("state") .. "/restart.vim"
  vim.cmd("mksession! " .. vim.fn.fnameescape(session))
  vim.cmd("restart +qall! silent! source " .. vim.fn.fnameescape(session))
end, { desc = "Restart Neovim (keep open files)" })
