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

    -- Move the clock out of section z.
    --
    -- In every lualine theme, z shares the bright accent colour with section a
    -- (the mode indicator) -- here #82aaff on both ends. That gave the time the
    -- same visual weight as "am I in insert mode", which is the loudest thing
    -- on the bar for the least useful information. Section y uses the medium
    -- background (#3b4261), which is the right level for it.
    --
    -- Delete this block to restore the stock bright clock; delete the clock
    -- component instead if you would rather not have the time at all.
    local z = opts.sections.lualine_z
    if z and z[1] then
      table.insert(opts.sections.lualine_y, z[1])
      opts.sections.lualine_z = {}
    end

    -- Next departure home (see lua/config/ruter.lua). Refreshed on a
    -- background timer, so this only reads a cached string. Shows nothing when
    -- there is no journey -- which includes the common case of already being
    -- at home, where origin and destination are the same place.
    local ruter = require("config.ruter")
    ruter.setup()
    table.insert(opts.sections.lualine_y, 1, {
      ruter.component,
      color = ruter.color,
      cond = function()
        return ruter.state.text ~= ""
      end,
    })

    -- Terminals (Claude, Copilot, the shell): name what is running instead of
    -- the buffer's term://…/bin/claude path, and drop the cursor position and
    -- scroll percentage, which only describe the scrollback.
    local function is_term()
      return vim.bo.buftype == "terminal"
    end
    local function not_term()
      return not is_term()
    end
    for _, section in ipairs({ opts.sections.lualine_c, opts.sections.lualine_y }) do
      for i, c in ipairs(section) do
        local comp = type(c) == "table" and c or { c }
        -- the path, filetype and diagnostics in c; progress and location in y
        if section == opts.sections.lualine_c or comp[1] == "progress" or comp[1] == "location" then
          local cond = comp.cond
          comp.cond = function()
            return not_term() and (not cond or cond())
          end
          section[i] = comp
        end
      end
    end
    table.insert(opts.sections.lualine_c, {
      function()
        local t = vim.b.snacks_terminal
        local cmd = t and (type(t.cmd) == "table" and table.concat(t.cmd, " ") or t.cmd)
        -- term://{cwd}//{pid}:{cmd}
        cmd = cmd or vim.api.nvim_buf_get_name(0):match("^term://.-//%d+:(.*)$") or ""
        local prog = vim.fs.basename(vim.split(cmd, " ")[1] or "")
        if prog == "claude" then
          return "Claude Code"
        elseif prog == "copilot" then
          return "Copilot CLI"
        elseif prog == "agy" then
          return "Antigravity CLI"
        end
        return "Terminal" .. (prog ~= "" and (" (" .. prog .. ")") or "")
      end,
      icon = "\u{f120}", -- terminal
      cond = is_term,
    })

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
