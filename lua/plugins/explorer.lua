-- File explorer (snacks.nvim picker, LazyVim's default since it replaced neo-tree).
-- Keys are also documented by hand in lua/config/cheatsheet_data.lua -- see README.md.
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
    {
      "<leader>gC",
      function()
        require("config.changes").open()
      end,
      desc = "Changes sidebar",
    },
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
            scm_click = {
              action = function(picker)
                if picker.opts.scm then
                  require("config.explorer_changes").click(picker)
                end
              end,
              desc = "Row buttons (stage / unstage / discard / menu, branch name)",
            },
            scm_stage_add = {
              action = function(picker, item)
                require("config.explorer_changes").stage(picker, item)
              end,
              desc = "Stage",
            },
            scm_unstage = {
              action = function(picker, item)
                require("config.explorer_changes").unstage(picker, item)
              end,
              desc = "Unstage",
            },
            -- Discard in Source Control; in the tree these keys keep their
            -- usual jobs (<Del> deletes, <BS> goes up a folder)
            scm_discard_del = {
              action = function(picker, item)
                if picker.opts.scm then
                  return require("config.explorer_changes").discard(picker, item)
                end
                return picker:action("explorer_del")
              end,
              desc = "Discard changes / delete",
            },
            scm_discard_bs = {
              action = function(picker, item)
                if picker.opts.scm then
                  return require("config.explorer_changes").discard(picker, item)
                end
                return picker:action("explorer_up")
              end,
              desc = "Discard changes / up a folder",
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
            scm_pull = {
              action = function(picker, item)
                require("config.explorer_changes").pull(picker, item)
              end,
              desc = "Pull",
            },
            scm_branch = {
              action = function(picker, item)
                require("config.explorer_changes").branch(picker, item)
              end,
              desc = "Switch branch",
            },
            preview_file = {
              action = function(picker, item)
                local file = item and item.file or ""
                local ext = file:lower():match("%.(%w+)$")
                if ext == "pdf" then
                  require("config.preview").open_pdf(file)
                elseif ext == "md" or ext == "markdown" or ext == "mdx" then
                  require("config.preview").open_md(file, picker.main, picker.list.win.win)
                else
                  vim.notify("Space c p previews .pdf and .md files", vim.log.levels.INFO)
                end
              end,
              desc = "Preview PDF / Markdown (browser)",
            },
            noop = {
              action = function() end,
              desc = "Nothing",
            },
            scm_menu = {
              action = function(picker, item)
                require("config.explorer_changes").menu(picker, item)
              end,
              desc = "Git actions (pull, push, branches, stash...)",
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
                ["+"] = "scm_stage_add",
                -- the <LeftMouse> before it has already focused the list and
                -- moved the cursor, so this runs even when clicking in from
                -- the editor (same trick as the activity bar)
                ["<LeftRelease>"] = "scm_click",
                -- nothing to select in a file tree: a click that moved by a
                -- cell counted as a drag, started Visual mode and popped up
                -- which-key's Visual menu (the activity bar does the same)
                ["<LeftDrag>"] = "noop",
                ["-"] = "scm_unstage",
                ["<Del>"] = "scm_discard_del",
                ["<BS>"] = "scm_discard_bs",
                ["gc"] = "scm_commit",
                ["gp"] = "scm_push",
                ["gl"] = "scm_pull",
                ["gb"] = "scm_branch",
                ["gm"] = "scm_menu",
                -- same key as in a .pdf / .md buffer, on the hovered file
                ["<leader>cp"] = "preview_file",
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
