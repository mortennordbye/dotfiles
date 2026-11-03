-- Chromeless Chrome "app" window shared by the markdown and PDF previews:
-- no tab bar, address bar or bookmarks, so it tiles next to the terminal
-- like a VSCode preview pane. Set app_window = false for a plain tab.
local M = {}

M.app_window = true

function M.open_url(url)
  local chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  if M.app_window and vim.fn.executable(chrome) == 1 then
    vim.fn.jobstart({ chrome, "--app=" .. url, "--window-size=1000,1200" }, { detach = true })
  else
    vim.ui.open(url) -- default browser
  end
end

-- Chrome's built-in viewer shows every page; the in-buffer view only page 1.
function M.open_pdf(path)
  M.open_url(vim.uri_from_fname(vim.fn.fnamemodify(path, ":p")))
end

-- Markdown preview of a file that is not open yet (explorer: Space c p on
-- the hovered .md). markdown-preview renders loaded buffers only, so the file
-- is opened in the editor window `win`. On first start the server picks the
-- buffer of whichever window has focus once it is up, so focus stays on the
-- file until the page URL is handed out (User MkdpPageOpened, fired from the
-- browserfunc in lua/plugins/markdown.lua), then goes back to `back`.
function M.open_md(path, win, back)
  vim.api.nvim_set_current_win(win)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local function go_back()
    if vim.api.nvim_win_is_valid(back) then
      vim.api.nvim_set_current_win(back)
    end
  end
  if vim.g.mkdp_clients_active == 1 then
    -- combine mode: entering the buffer already switched the page to it
    return go_back()
  end
  local done = false
  local id = vim.api.nvim_create_autocmd("User", {
    pattern = "MkdpPageOpened",
    once = true,
    callback = function()
      done = true
      vim.schedule(go_back)
    end,
  })
  vim.cmd("MarkdownPreview")
  vim.defer_fn(function()
    if not done then
      pcall(vim.api.nvim_del_autocmd, id)
      go_back()
    end
  end, 5000)
end

return M
