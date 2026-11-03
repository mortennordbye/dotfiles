-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Let Neovim set the terminal window title so AltTab / the Ghostty tab bar show
-- which project each window is in. Format: "folder  file", e.g. "Homelab  README.md".
--
-- Deliberately minimal:
--   * cwd is shown as its tail ("Homelab"), except at $HOME where the tail is
--     the account name (first.last) and "~" is what you mean.
--   * an unnamed buffer (dashboard, scratch) contributes nothing rather than
--     the placeholder "[no name]".
--   * no "(nvim)" suffix -- the app is already obvious from the window itself.
-- These are %{} expressions, so Neovim re-evaluates them on redraw; no autocmd.
vim.opt.title = true
vim.opt.titlelen = 0 -- no truncation
vim.opt.titlestring = table.concat({
  "%{getcwd() ==# $HOME ? '~' : fnamemodify(getcwd(), ':t')}",
  "%{expand('%:t') == '' ? '' : '  ' . expand('%:t')}",
})

-- Rounded borders for every floating window (hover docs, diagnostics, rename,
-- lazy.nvim, mason, ...) without per-plugin border config. Native in nvim 0.11+.
-- The border colour is set in lua/plugins/colorscheme.lua (FloatBorder).
vim.o.winborder = "rounded"

-- Clearer separation between split windows: heavy solid lines instead of the
-- default thin ones. The colour is set in lua/plugins/colorscheme.lua
-- (WinSeparator highlight).
vim.opt.fillchars:append({
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
})
