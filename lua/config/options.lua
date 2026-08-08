-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Let Neovim set the terminal window title so AltTab / the Ghostty tab bar show
-- which project each window is in. Format: "folder  file  (nvim)".
vim.opt.title = true
vim.opt.titlelen = 0 -- no truncation
vim.opt.titlestring = "%{fnamemodify(getcwd(), ':t')}  %{expand('%:t') == '' ? '[no name]' : expand('%:t')}  (nvim)"

-- Clearer separation between split windows: heavy solid lines instead of the
-- default thin ones. The color is set in autocmds.lua (WinSeparator highlight).
vim.opt.fillchars:append({
  horiz = "━",
  horizup = "┻",
  horizdown = "┳",
  vert = "┃",
  vertleft = "┫",
  vertright = "┣",
  verthoriz = "╋",
})
