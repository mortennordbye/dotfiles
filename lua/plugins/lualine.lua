-- Statusline: always show the current working directory.
--
-- LazyVim's stock lualine only renders a folder via its `root_dir` component, and
-- that one hides itself whenever the project root equals cwd -- i.e. most of the
-- time. Everything else on the left (diagnostics, filetype icon, file path) is
-- per-buffer, so focusing the file explorer or a terminal leaves the left side
-- showing nothing but the mode and the git branch.
--
-- This component reads cwd directly, so it survives both cases. `root_dir` is left
-- alone: it still appears when the root differs from cwd (monorepo subdirectories),
-- where knowing both is actually useful.
return {
  "nvim-lualine/lualine.nvim",
  optional = true,
  opts = function(_, opts)
    table.insert(opts.sections.lualine_c, 1, {
      function()
        return vim.fn.fnamemodify(vim.uv.cwd() or "", ":~")
      end,
      icon = "󰉋",
      color = function()
        return { fg = Snacks.util.color("Directory") }
      end,
    })
  end,
}
