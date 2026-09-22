-- File explorer (snacks.nvim picker, LazyVim's default since it replaced neo-tree).
-- Keys are also documented by hand in a cheatsheet outside this repo -- see README.md.
return {
  "folke/snacks.nvim",
  init = function()
    -- Git status for folders that hold several repos; see lua/config/explorer_git.lua.
    package.preload["snacks.explorer.git"] = function(name)
      package.preload[name] = nil
      local Git = dofile(vim.api.nvim_get_runtime_file("lua/snacks/explorer/git.lua", false)[1])
      require("config.explorer_git").patch(Git)
      return Git
    end
    -- Keep the explorer's confirm (<CR>, l, double-click) off the Source
    -- Control divider and header rows; see lua/config/explorer_changes.lua.
    package.preload["snacks.explorer.actions"] = function(name)
      package.preload[name] = nil
      local Actions = dofile(vim.api.nvim_get_runtime_file("lua/snacks/explorer/actions.lua", false)[1])
      require("config.explorer_changes").patch_actions(Actions)
      return Actions
    end
  end,
  keys = {
    { "<leader>gC", function() require("config.changes").open() end, desc = "Changes sidebar" },
  },
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

          -- Opened with `scm = true` this is the Source Control panel instead of the
          -- tree (activity bar button); see lua/config/explorer_changes.lua
          finder = function(opts, ctx)
            return require("config.explorer_changes").finder(opts, ctx)
          end,
          format = function(item, picker)
            return require("config.explorer_changes").format(item, picker)
          end,
          actions = {
            scm_stage = {
              action = function(picker, item)
                require("config.explorer_changes").toggle_stage(picker, item)
              end,
              desc = "Stage / unstage",
            },
            scm_commit = {
              action = function(picker, item)
                require("config.explorer_changes").commit(picker, item)
              end,
              desc = "Commit",
            },
            scm_push = {
              action = function(picker, item)
                require("config.explorer_changes").push(picker, item)
              end,
              desc = "Push",
            },
          },

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
              keys = {
                ["s"] = "scm_stage",
                ["gc"] = "scm_commit",
                ["gp"] = "scm_push",
                -- swap to the changed-files-only view; see lua/config/changes.lua
                ["C"] = {
                  function(picker)
                    local dir = picker:cwd()
                    picker:close()
                    require("config.changes").open(dir)
                  end,
                  desc = "Changes only",
                },
              },
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
