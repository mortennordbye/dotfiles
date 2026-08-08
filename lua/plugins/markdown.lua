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

  -- On-demand HTML preview in the browser (already from lang.markdown extra).
  -- Keymap <leader>cp is provided by LazyVim; this just documents/ensures it.
  {
    "iamcco/markdown-preview.nvim",
    keys = {
      {
        "<leader>cp",
        "<cmd>MarkdownPreviewToggle<cr>",
        ft = "markdown",
        desc = "Markdown HTML Preview (browser)",
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
