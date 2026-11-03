-- Free insert-mode <C-k> for "go to the window above" (lua/config/keymaps.lua).
--
-- Both of these map it buffer-locally, which beats a global mapping, so with
-- either left on <C-k> would move you in some files and not in others.
-- Signature help is still on gK in normal mode.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          keys = {
            { "<c-k>", false, mode = "i" },
          },
        },
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-k>"] = false,
      },
    },
  },
}
