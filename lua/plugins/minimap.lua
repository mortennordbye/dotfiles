-- VSCode-style minimap: a zoomed-out outline of the file on the right edge of
-- each editor window, so you can see how long the file is and where you are.
-- Keys are also documented by hand in a cheatsheet outside this repo -- see README.md.
--
-- layout = "float" attaches one minimap to each editor window rather than one
-- split per tab, so it follows splits and never lands on top of the Claude or
-- Copilot panel. Terminals, the explorer and the dashboard are skipped by
-- neominimap's default buftype excludes (terminal / nofile).
--
-- Made to look like VSCode's rather than neominimap's default box:
--   * no border, 12 columns wide (x_multiplier 4 still covers ~96 columns of code)
--   * background is the editor's own, not the float colour
--   * git changes are line highlights, not signs, so no sign column opens inside it
--   * only as tall as the map itself (one row per 4 lines of code), capped at the
--     window height. neominimap always sizes the float to the full window height
--     and has no option for this, so refresh_minimap_window is wrapped below.
--   * current_line_position = "percent": when the map is taller than the window it
--     scrolls proportionally like VSCode's, and when it fits it never scrolls.
--
-- The float covers the right-most columns of the window it is attached to.
-- That is harmless with wrap off (sidescrolloff below keeps the cursor clear of
-- it), but in wrapped windows it would hide the ends of lines, so windows with
-- wrap on get no minimap. LazyVim turns wrap on for markdown/text/gitcommit.
local width = 12

--- Shrink a minimap float to the number of lines in its map buffer.
---@param mwinid integer?
local function fit_height(mwinid)
  if not (mwinid and vim.api.nvim_win_is_valid(mwinid)) then
    return
  end
  local rows = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(mwinid))
  if vim.api.nvim_win_get_height(mwinid) > rows then
    vim.api.nvim_win_set_config(mwinid, { height = rows })
  end
end

return {
  "Isrothy/neominimap.nvim",
  version = "v3.x.x", -- fit_height hooks an internal module; recheck on a major bump
  lazy = false, -- upstream: the plugin lazy-loads itself, do not defer it
  init = function()
    vim.opt.sidescrolloff = width + 4 -- keep the cursor clear of the float

    ---@type Neominimap.UserConfig
    vim.g.neominimap = {
      auto_enable = true,
      layout = "float",
      float = {
        minimap_width = width,
        window_border = "none",
      },
      current_line_position = "percent",
      exclude_filetypes = {
        "help",
        "bigfile", -- snacks.nvim
        "markdown",
        "text",
        "gitcommit",
      },
      win_filter = function(winid)
        return not vim.wo[winid].wrap
      end,
      winopt = function(opt)
        opt.winhighlight = opt.winhighlight:gsub("Normal:NeominimapBackground", "Normal:Normal")
      end,
      click = { enabled = true }, -- click a spot in the minimap to jump there
      git = { enabled = true, mode = "line" },
      diagnostic = { enabled = true, mode = "line" },
      search = { enabled = true, mode = "line" },
    }
  end,
  config = function()
    -- Every neominimap event looks this function up on the module table, so
    -- replacing the field is enough to apply fit_height after each resize.
    local float = require("neominimap.window.float.internal")
    local refresh = float.refresh_minimap_window
    float.refresh_minimap_window = function(winid)
      local mwinid = refresh(winid)
      fit_height(mwinid)
      return mwinid
    end

    -- A finished map render (and every later text edit) only moves the map's
    -- cursor line; it does not refresh the float. Without this the float keeps
    -- the height it had when it opened on a still-empty map buffer: 1 row.
    -- Hooked the same way rather than with an own autocmd, because the plugin
    -- fires this event with group = "Neominimap", which runs no other group.
    local autocmds = require("neominimap.window.float.autocmds")
    local text_changed = autocmds.on_minimap_buffer_text_changed
    autocmds.on_minimap_buffer_text_changed = function(args)
      text_changed(args)
      vim.schedule(function()
        for _, winid in ipairs(require("neominimap.util").get_attached_window(args.data.buffer)) do
          float.refresh_minimap_window(winid)
        end
      end)
    end

    Snacks.toggle({
      name = "Minimap",
      get = function()
        return require("neominimap.api").enabled()
      end,
      set = function(state)
        if state then
          require("neominimap.api").enable()
        else
          require("neominimap.api").disable()
        end
      end,
    }):map("<leader>uM")
  end,
}
