-- Lock Layout: keep the editor, the side panels and the terminals in their
-- own places, like VSCode's editor area, which never disappears.
--
-- Without it the layout can fall apart in two ways:
--
--   1. Close the last file window (:q, :bd, <C-w>c) and only the explorer and
--      the Claude panel are left. The next file opened from the explorer then
--      has nowhere to go: snacks' picker falls back to any split
--      (snacks/picker/core/main.lua, `wins[1] or non_float`), which is often
--      the Claude terminal, and the file replaces it.
--   2. From terminal normal mode in a panel, <C-o>, :e or a buffer switch
--      loads a file into the panel window itself.
--
-- While locked:
--   * closing the last editor window opens a new one where it was, and the
--     panels keep their size;
--   * terminal panels get 'winfixbuf', so nothing else can be loaded into
--     them, and 'winfixwidth' / 'winfixheight', so opening and closing other
--     splits doesn't squash them.
--
-- Toggle with <leader>uP (lua/config/keymaps.lua) or the lock icon in the activity bar. The choice is
-- kept across restarts.

local M = {}

local state_file = vim.fn.stdpath("state") .. "/layout_lock.json"

M.locked = true
do
  local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n")) end)
  if ok and type(data) == "table" and type(data.locked) == "boolean" then
    M.locked = data.locked
  end
end

---@param w integer
local function is_float(w)
  return vim.api.nvim_win_get_config(w).relative ~= ""
end

-- A window for editing files: a normal buffer in a normal split.
---@param w integer
local function is_editor(w)
  if not vim.api.nvim_win_is_valid(w) or is_float(w) then
    return false
  end
  local b = vim.api.nvim_win_get_buf(w)
  return vim.bo[b].buftype == "" and vim.bo[b].filetype ~= "activitybar" and not vim.w[w].snacks_layout
end

-- A terminal panel (Claude, Copilot, Antigravity, the shell) in a split.
---@param w integer
local function is_term_panel(w)
  return vim.api.nvim_win_is_valid(w)
    and not is_float(w)
    and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "terminal"
end

-- A side panel is narrower than most of the screen; a bottom one spans it.
---@param w integer
local function is_side(w)
  return vim.api.nvim_win_get_width(w) < vim.o.columns * 0.8
end

---@param w integer
local function pin(w)
  local wo = vim.wo[w]
  wo.winfixbuf = M.locked
  if is_side(w) then
    wo.winfixwidth = M.locked
  else
    wo.winfixheight = M.locked
  end
end

local function pin_all()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if is_term_panel(w) then
      pin(w)
    end
  end
end

-- The buffer to show in the recreated editor window: the last file used,
-- other than the one whose window was just closed; an empty one otherwise.
---@param closed integer
local function pick_buf(closed)
  local best, used = nil, -1
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if info.bufnr ~= closed and vim.bo[info.bufnr].buftype == "" and info.lastused > used then
      best, used = info.bufnr, info.lastused
    end
  end
  return best or vim.api.nvim_create_buf(true, false)
end

-- Where the closing window sits in the layout tree: a neighbour in the same
-- row or column, and the side of it the window was on. Splitting that
-- neighbour puts a new window back in the same frame, whatever else is
-- around it (a bottom terminal under everything, one under the editor only).
---@param tab integer
---@param closing integer
---@return {win: integer, split: string}?
local function slot(tab, closing)
  local function find(node, parent, i)
    if node[1] == "leaf" then
      if node[2] == closing then
        return parent, i
      end
      return
    end
    for j, child in ipairs(node[2]) do
      local p, k = find(child, node, j)
      if p then
        return p, k
      end
    end
  end
  local parent, i = find(vim.fn.winlayout(vim.api.nvim_tabpage_get_number(tab)))
  if not parent then
    return
  end
  local row = parent[1] == "row"
  local prev, next = parent[2][i - 1], parent[2][i + 1]
  -- the nearest window of a neighbour: its first one when it comes after,
  -- its last one when it comes before
  local function edge(node, last)
    while node[1] ~= "leaf" do
      node = node[2][last and #node[2] or 1]
    end
    return node[2]
  end
  -- prefer a neighbour that is a single window; splitting inside a group of
  -- windows would put the editor in that group's frame
  if next and (next[1] == "leaf" or not prev or prev[1] ~= "leaf") then
    return { win = edge(next, false), split = row and "left" or "above" }
  elseif prev then
    return { win = edge(prev, true), split = row and "right" or "below" }
  end
end

---@param tab integer
---@param closed_buf integer
---@param where {win: integer, split: string}?
---@param sizes table<integer, {width: integer, height: integer}>
local function restore(tab, closed_buf, where, sizes)
  if not M.locked or vim.v.exiting ~= vim.NIL or not vim.api.nvim_tabpage_is_valid(tab) then
    return
  end
  local wins = vim.api.nvim_tabpage_list_wins(tab)
  for _, w in ipairs(wins) do
    if is_editor(w) then
      return -- something already put one back
    end
  end
  -- nothing but the activity bar and floats left: nvim is on its way out
  local splits = vim.tbl_filter(function(w)
    return not is_float(w) and vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "activitybar"
  end, wins)
  if #splits == 0 then
    return
  end
  if not (where and vim.api.nvim_win_is_valid(where.win) and vim.api.nvim_win_get_tabpage(where.win) == tab) then
    -- the neighbour went too: take the rest of the width, full height
    where = { win = -1, split = "right" }
  end

  local ea = vim.o.equalalways
  vim.o.equalalways = false
  local ok, win = pcall(vim.api.nvim_open_win, pick_buf(closed_buf), true, { split = where.split, win = where.win })
  -- the new split took its room from its neighbours; give them their size back
  for w, size in pairs(sizes) do
    if vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_set_width, w, size.width)
      pcall(vim.api.nvim_win_set_height, w, size.height)
    end
  end
  vim.o.equalalways = ea
  if ok then
    vim.api.nvim_set_current_win(win)
    vim.cmd("stopinsert")
  end
end

function M.set(locked)
  M.locked = locked
  pcall(vim.fn.writefile, { vim.json.encode({ locked = locked }) }, state_file)
  pin_all()
  local bar = package.loaded["config.activitybar"]
  if bar and bar.refresh then
    bar.refresh()
  end
end

function M.toggle()
  M.set(not M.locked)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("layout_lock", { clear = true })

  vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter", "WinNew" }, {
    group = group,
    callback = vim.schedule_wrap(pin_all),
  })

  -- WinClosed runs before the window leaves the layout, so its place in the
  -- layout and the panel sizes read here are still the ones to go back to.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(ev)
      local closing = tonumber(ev.match)
      if not (M.locked and closing and is_editor(closing)) then
        return
      end
      local tab = vim.api.nvim_win_get_tabpage(closing)
      local sizes = {}
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if w ~= closing then
          if is_editor(w) then
            return -- another editor window stays; nothing to do
          end
          -- terminals, and the explorer's frame window
          if is_term_panel(w) or vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_layout_box" then
            sizes[w] = { width = vim.api.nvim_win_get_width(w), height = vim.api.nvim_win_get_height(w) }
          end
        end
      end
      local closed_buf, where = ev.buf, slot(tab, closing)
      vim.schedule(function() restore(tab, closed_buf, where, sizes) end)
    end,
  })

end

return M
