-- Claude Code panel (coder/claudecode.nvim, from lazyvim.plugins.extras.ai.claudecode).
--
-- This file replaces the old lua/plugins/claude.lua, which pulled in a SECOND
-- integration (greggh/claude-code.nvim) on <leader>cc. Two problems with that:
--
--   1. Both plugins were installed and each could start its own Claude session.
--   2. <leader>cc is LazyVim's "Run Codelens", which is a buffer-local LSP
--      mapping and therefore wins wherever a language server is attached. So
--      <leader>cc ran codelens, not Claude, in exactly the files you edit most.
--
-- The extra's keys are the <leader>a* group: ac toggle, af focus, ar resume,
-- aC continue, ab add buffer, as send selection, aa/ad accept/deny diff.
--
-- Terminal behaviour is snacks.nvim's; see lua/plugins/terminal.lua for why
-- snacks' double-<esc> mapping is turned off (it stole Claude's interrupt).
return {
  "coder/claudecode.nvim",
  init = function()
    -- Keep diffs off the activity bar (lua/config/activitybar.lua).
    --
    -- claudecode opens a diff in the first window that isn't a terminal, a
    -- float or a known sidebar. The bar is none of those and is the first
    -- window in the tab, so every diff targeted it and failed with E1513 (the
    -- bar has 'winfixbuf'), leaving stray splits of the Claude window behind.
    -- The window finder is local to the module with no option to extend it, so
    -- add the bar's filetype to its exclusion lists as the module loads, the
    -- same way lua/plugins/explorer.lua patches snacks.
    package.preload["claudecode.diff"] = function(name)
      package.preload[name] = nil
      local path = vim.api.nvim_get_runtime_file("lua/claudecode/diff.lua", false)[1]
      local src = table.concat(vim.fn.readfile(path), "\n")
      local patched, n = src:gsub(
        'or filetype == "snacks_layout_box"',
        'or filetype == "snacks_layout_box" or filetype == "activitybar"'
      )
      if n == 0 then
        vim.notify(
          "claudecode.diff changed upstream: diffs may land on the activity bar (see lua/plugins/claudecode.lua)",
          vim.log.levels.WARN
        )
        return dofile(path)
      end
      return assert(loadstring(patched, "@" .. path))()
    end

    -- `nvim .` (or any single folder argument) is "start working in this
    -- project", so open the Claude panel alongside the explorer straight away.
    -- A file argument or a bare `nvim` (start screen) is left alone.
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("claudecode_on_dir", { clear = true }),
      once = true,
      callback = function()
        if vim.fn.argc() ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) == 0 then
          return
        end
        -- after the explorer has claimed the left side
        vim.schedule(function()
          -- the extra lazy-loads on its keys, so the command isn't defined yet
          require("lazy").load({ plugins = { "claudecode.nvim" } })
          vim.cmd("ClaudeCode")
        end)
      end,
    })
  end,
  opts = {
    terminal = {
      split_side = "right",

      -- 0.30 is the plugin default. Claude's prose and code blocks wrap hard at
      -- that width on a wide display; the extra few percent removes most of the
      -- reflow without meaningfully squeezing the editor.
      split_width_percentage = 0.38,

      -- While a diff is open the diff needs the room more than the transcript
      -- does, so give the terminal less and hand the difference to the diff.
      -- Restored automatically when the diff closes.
      diff_split_width_percentage = 0.28,

      snacks_win_opts = {
        wo = {
          -- Name the pane. Without this it is an unlabelled terminal sitting
          -- next to the editor, which is ambiguous once there is more than one
          -- split open.
          winbar = " Claude Code ",
          number = false,
          relativenumber = false,
          signcolumn = "no",
          statuscolumn = "",
          cursorline = false,
        },
      },
    },
  },
}
