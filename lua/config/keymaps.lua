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

-- Leave terminal mode. Deliberately NOT <Esc> or <Esc><Esc>: Claude Code uses Esc
-- as its interrupt and Esc Esc for rewind, so any mapping there either steals those
-- keys or delays them by 'timeoutlen'. <C-q> is unused by Claude and by nvim in
-- terminal mode, and q needs no modifier on a Norwegian layout.
-- (snacks' own double-esc mapping is disabled in lua/plugins/terminal.lua.)
map("t", "<C-q>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Make the <C-w> window prefix work INSIDE terminals too. Exits terminal mode
-- first, then starts the window command — so e.g. <C-w>L moves a terminal to
-- the right side without needing Ctrl+\ (which is awkward on a Norwegian layout).
-- Shell/Claude word-delete is still available via Option+Delete.
map("t", "<C-w>", "<C-\\><C-n><C-w>", { desc = "Window command (from terminal)" })

-- Reload files from disk (handy when edited externally, e.g. by Claude Code,
-- while open here). <leader>br = safe reload of any changed buffers;
-- <leader>bR = force-reload current buffer (discards local unsaved changes).
map("n", "<leader>br", "<cmd>checktime<cr>", { desc = "Reload changed files from disk" })
map("n", "<leader>bR", "<cmd>edit!<cr>", { desc = "Force reload buffer (discard changes)" })

-- Show / hide the VSCode-style activity bar (lua/config/activitybar.lua).
map("n", "<leader>uA", function() require("config.activitybar").toggle() end, { desc = "Toggle Activity Bar" })

-- Keybinding cheatsheet (lua/config/cheatsheet.lua; content in cheatsheet_data.lua).
map("n", "<leader>h", function() require("config.cheatsheet").open() end, { desc = "Cheatsheet" })
