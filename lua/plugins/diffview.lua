-- VSCode-style Source Control.
--
-- GitUi (<leader>gg) is a full-screen modal TUI: it takes over the window and
-- brings its own keybindings. diffview is the opposite -- ordinary Neovim
-- windows, ordinary keys -- and matches how VSCode presents git: a panel of
-- changed files on one side, a real side-by-side diff in the main area.
--
-- GitUi is deliberately kept on <leader>gg as the escape hatch for the things
-- diffview does not do: interactive rebase, stash juggling, remotes.
--
-- gitsigns still owns the in-buffer hunk workflow (]h / [h, <leader>gh*), which
-- is the equivalent of VSCode's gutter marks. diffview is the review surface.
--
-- Keys avoid the crowded <leader>g space already taken by snacks pickers,
-- gitsigns and the gh extra: gd, gs, gb, gg, gl, gm, gi, gp, gS, gY, gh* are
-- all in use, so diffview lives on gv / gV / gf / gF.
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles" },
  opts = {
    enhanced_diff_hl = true, -- clearer intra-line highlighting than plain diff
    file_panel = {
      listing_style = "tree",
      tree_options = { flatten_dirs = true },
      win_config = {
        position = "left", -- same side VSCode puts Source Control
        width = 34, -- matches the snacks explorer width
      },
    },
    view = {
      -- Three-way view when resolving conflicts: local, base and incoming,
      -- which is closer to VSCode's merge editor than a plain two-way diff.
      merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
    },
  },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Source Control (diffview)" },
    { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Close diffview" },
    -- gH, not the more obvious gf: the gitui extra deletes <leader>gf and
    -- <leader>gl outright on the LazyVimKeymaps event (it strips LazyVim's
    -- lazygit-oriented bindings), which silently removed this mapping too.
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "History (this file)" },
    { "<leader>gF", "<cmd>DiffviewFileHistory<cr>", desc = "History (branch)" },
  },
}
