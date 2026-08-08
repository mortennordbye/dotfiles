-- File explorer (snacks.nvim picker, LazyVim's default since it replaced neo-tree).
-- Keys are also documented by hand in a cheatsheet outside this repo -- see README.md.
return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      -- Softer tree guides than the default ├╴ └╴
      icons = {
        tree = {
          vertical = "│  ",
          middle = "├─ ",
          last = "└─ ",
        },
      },
      sources = {
        explorer = {
          hidden = true, -- show dotfiles (.env, .github, ...)
          ignored = true, -- show gitignored files, dimmed
          -- Noise we never want to see even with hidden/ignored on
          exclude = { ".git", ".DS_Store" },

          -- Richer signals in the tree
          git_status_open = true, -- git status on files inside opened dirs, not just the dir
          diagnostics_open = true, -- same for LSP diagnostics
          follow_file = true, -- reveal the buffer you jump to

          layout = {
            preset = "sidebar",
            preview = false, -- toggle on demand with P
            layout = {
              width = 36,
              min_width = 36,
            },
          },

          win = {
            list = {
              wo = {
                number = false,
                relativenumber = false,
                signcolumn = "no",
                statuscolumn = "",
                cursorline = true,
                winbar = "",
              },
            },
          },
        },
      },
    },
  },
}
