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
    -- Powerline-style angled section separators (Nerd Font glyphs). LazyVim
    -- ships flat blocks; these make the mode/branch/diagnostics groups read as
    -- distinct segments instead of one run-on bar.
    -- Written as \u{...} escapes rather than literal glyphs: these live in the
    -- Unicode private use area, so they do not survive every editor/pipeline
    -- that touches this file and silently degrade to empty strings.
    --   e0b0 / e0b2 = solid powerline triangles (section edges)
    --   e0b1 / e0b3 = thin powerline chevrons (between components)
    opts.options = opts.options or {}
    opts.options.section_separators = { left = "\u{e0b0}", right = "\u{e0b2}" }
    opts.options.component_separators = { left = "\u{e0b1}", right = "\u{e0b3}" }
    opts.options.globalstatus = true

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
