-- Languages LazyVim has no extra for: Bicep (Azure templates) and PowerShell.
-- Both servers come from Mason; syntax highlighting from treesitter.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- nvim-lspconfig ships no cmd for bicep; Mason's bicep-lsp package
        -- puts this wrapper on the path (it needs the dotnet runtime)
        bicep = {
          cmd = { "bicep-lsp" },
        },
        -- PowerShell Editor Services is a folder of scripts started by pwsh,
        -- not a binary, so lspconfig needs to know where Mason unpacked it.
        -- Without pwsh lspconfig's cmd returns nil and nvim 0.12 crashes on
        -- every PowerShell buffer, so stay off until it's installed.
        powershell_es = {
          enabled = vim.fn.executable("pwsh") == 1,
          bundle_path = vim.fn.stdpath("data") .. "/mason/packages/powershell-editor-services",
          settings = { powershell = { codeFormatting = { Preset = "OTBS" } } },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "bicep", "powershell" } },
  },
}
