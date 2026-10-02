-- Open the browser preview in a chromeless Chrome "app" window instead of a
-- normal tab, so it can be tiled next to Ghostty like a VSCode preview pane.
-- Set to false to go back to a plain tab in the default browser.
local preview_in_app_window = true

-- Chrome's --app= gives a window with no tab bar, address bar or bookmarks:
-- just the rendered document. Falls back to the default browser/app.
local function open_in_app_window(url)
  local chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  if vim.fn.executable(chrome) == 1 then
    vim.fn.jobstart({ chrome, "--app=" .. url, "--window-size=1000,1200" }, { detach = true })
  else
    vim.fn.jobstart({ "open", url }, { detach = true })
  end
end

return {
  -- Keep the .md buffer as RAW markdown by default.
  -- render-markdown.nvim (in-buffer prettifier) starts off; toggle when wanted.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = { enabled = false },
    keys = {
      {
        "<leader>um",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Toggle in-buffer Markdown render",
      },
    },
  },

  -- HTML preview in the browser, tuned to behave like the VSCode preview:
  -- one tab that stays open, follows whichever markdown buffer you are in,
  -- and re-renders on every change (undo, :s, formatters, external writes).
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    init = function()
      -- The plugin default closes the browser tab on BufHidden, so the
      -- preview dies the moment you switch buffer. VSCode keeps it open.
      vim.g.mkdp_auto_close = 0

      -- Reuse one browser tab and re-point it at the markdown buffer you
      -- enter, instead of one tab per file. No focus steal: with a client
      -- already connected the server only tells the page to switch buffer.
      vim.g.mkdp_combine_preview = 1
      vim.g.mkdp_combine_preview_auto_refresh = 1

      -- 0 = live refresh while editing (1 would only refresh on write /
      -- InsertLeave / CursorHold).
      vim.g.mkdp_refresh_slow = 0

      if preview_in_app_window then
        vim.g.mkdp_browserfunc = "MkdpOpenPreviewWindow"
      end

      vim.g.mkdp_theme = vim.o.background == "light" and "light" or "dark"
      vim.g.mkdp_page_title = "${name}"
      vim.g.mkdp_echo_preview_url = 1

      vim.g.mkdp_preview_options = {
        mkit = {},
        katex = {},
        uml = {},
        maid = {},
        disable_sync_scroll = 0,
        sync_scroll_type = "relative", -- track the cursor line like VSCode
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 1,
        toc = { listType = "ul" }, -- put [[toc]] in a doc to get a table of contents
      }
    end,
    keys = {
      {
        "<leader>cp",
        -- Not MarkdownPreviewToggle: that toggle is tracked per buffer
        -- (b:MarkdownPreviewToggleBool), so once the preview starts following
        -- other files it no longer knows it is open. g:mkdp_clients_active is
        -- set by the server when a browser page connects, so it is true no
        -- matter which markdown buffer you are standing in.
        function()
          vim.cmd(vim.g.mkdp_clients_active == 1 and "MarkdownPreviewStop" or "MarkdownPreview")
        end,
        ft = "markdown",
        desc = "Markdown HTML Preview (browser)",
      },
      { "<leader>cP", "<cmd>MarkdownPreview<cr>", ft = "markdown", desc = "Markdown Preview: re-open window" },
    },
    config = function()
      vim.cmd([[do FileType]])

      -- g:mkdp_browserfunc is called by the server as a Vimscript function
      -- with the preview URL.
      _G.MkdpOpenPreviewWindow = open_in_app_window
      vim.cmd([[
        function! MkdpOpenPreviewWindow(url) abort
          call luaeval('_G.MkdpOpenPreviewWindow(_A)', a:url)
        endfunction
      ]])

      local group = vim.api.nvim_create_augroup("mkdp_extra_refresh", { clear = true })
      local md = { "*.md", "*.markdown", "*.mdx" }

      -- Upstream only refreshes on CursorHold/CursorMoved, so any edit that
      -- does not move the cursor never reaches the page. Push a refresh on
      -- the actual change events too.
      vim.api.nvim_create_autocmd(
        { "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost", "FileChangedShellPost" },
        {
          group = group,
          pattern = md,
          callback = function()
            if vim.g.mkdp_clients_active == 1 then
              vim.fn["mkdp#rpc#preview_refresh"]()
            end
          end,
        }
      )

      -- Pick up writes made outside nvim (agents, other editors) so the
      -- refresh above has something new to send.
      vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
        group = group,
        pattern = md,
        command = "silent! checktime",
      })
    end,
  },

  -- Same key on a PDF opens it in the same kind of chromeless window, using
  -- Chrome's built-in PDF viewer (the in-buffer view only shows page 1).
  {
    "folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("pdf_preview_key", { clear = true }),
        pattern = "*.pdf",
        callback = function(ev)
          vim.keymap.set("n", "<leader>cp", function()
            local path = vim.api.nvim_buf_get_name(ev.buf)
            if preview_in_app_window then
              open_in_app_window(vim.uri_from_fname(path))
            else
              vim.fn.jobstart({ "open", path }, { detach = true })
            end
          end, { buffer = ev.buf, desc = "PDF Preview (browser)" })
        end,
      })
    end,
  },

  -- Jump between the markdown files in the project. The browser preview is in
  -- combine mode, so whatever you land on becomes the previewed document --
  -- this is the "open another doc in the preview" half of VSCode's explorer,
  -- driven from nvim instead of from the page (see README for why).
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>fm",
        function()
          Snacks.picker.files({
            ft = { "md", "markdown", "mdx" },
            hidden = true,
            title = "Markdown files",
          })
        end,
        desc = "Markdown files (preview follows)",
      },
    },
  },

  -- Turn OFF the on-save markdown formatter (prettier/markdownlint).
  -- resultat.md is machine-generated; reformatting would reflow tables and
  -- could mangle the hidden JSON data block.
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        markdown = {},
        ["markdown.mdx"] = {},
      },
    },
  },

  -- And skip markdown linting noise.
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        markdown = {},
      },
    },
  },
}
