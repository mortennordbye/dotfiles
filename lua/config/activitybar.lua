-- Activity bar: VSCode's strip of icons down the left edge.
--
-- A narrow split pinned to the far left of the tab. Each icon opens (or, when
-- it is already open, closes) one panel: Explorer and Source Control share the
-- sidebar the way they do in VSCode, the rest toggle their own panels. Click an
-- icon, or move onto it with j/k and press <CR>. The icon of an open panel is
-- lit and gets the accent stripe on its left.
--
-- Sidebars open with `vertical topleft`, which would push past the bar, so any
-- new window moves the bar back to the edge (see `pin`).

local M = {}

local WIDTH = 5 -- LazyVim sets winminwidth=5; anything narrower gets widened back
local FT = "activitybar"

-- The explorer picker, either as the file tree or (`scm`) as Source Control.
---@param scm boolean
local function sidebar(scm)
  for _, p in ipairs(Snacks.picker.get({ source = "explorer" })) do
    if (p.opts.scm == true) == scm then
      return p
    end
  end
end

-- Close whichever sidebar is open and return the folder it was showing, so
-- the one replacing it opens on the same project.
---@return string
local function close_sidebars()
  local cwd
  for _, p in ipairs(Snacks.picker.get()) do
    if p.opts.source == "explorer" or p.opts.title == "Changes" then
      cwd = cwd or p:cwd()
      p:close()
    end
  end
  return cwd or LazyVim.root()
end

-- Hand focus back to an editor window, so commands that act on "the current
-- project" (LazyVim.root) see a real buffer rather than the bar.
local function leave_bar()
  if vim.bo.filetype == FT then
    vim.cmd("wincmd p")
    if vim.bo.filetype == FT then
      vim.cmd("wincmd l")
    end
  end
end

---@param match fun(cmd: string?): boolean
local function terminal_visible(match)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local t = vim.b[vim.api.nvim_win_get_buf(win)].snacks_terminal
    if t then
      local cmd = type(t.cmd) == "table" and table.concat(t.cmd, " ") or t.cmd
      if match(cmd) then
        return true
      end
    end
  end
  return false
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "m", false)
end

---@class activitybar.Item
---@field icon string
---@field name string
---@field run fun()
---@field active? fun(): boolean
---@field bottom? boolean

---@type activitybar.Item[]
M.items = {
  {
    icon = "",
    name = "Explorer",
    active = function() return sidebar(false) ~= nil end,
    run = function()
      local open = sidebar(false)
      local cwd = close_sidebars()
      if not open then
        leave_bar()
        Snacks.explorer({ cwd = cwd })
      end
    end,
  },
  {
    icon = "",
    name = "Search",
    run = function()
      leave_bar()
      Snacks.picker.grep({ cwd = LazyVim.root() })
    end,
  },
  {
    icon = "",
    name = "Source Control",
    active = function() return sidebar(true) ~= nil end,
    run = function()
      local open = sidebar(true)
      local cwd = close_sidebars()
      if not open then
        leave_bar()
        -- lua/config/explorer_changes.lua
        Snacks.explorer({ cwd = cwd, scm = true, title = "Source Control", follow_file = false })
      end
    end,
  },
  {
    icon = "󰚩",
    name = "Claude Code",
    active = function()
      return terminal_visible(function(cmd) return cmd ~= nil and cmd:find("claude") ~= nil end)
    end,
    run = function()
      leave_bar()
      require("lazy").load({ plugins = { "claudecode.nvim" } })
      vim.cmd("ClaudeCode")
    end,
  },
  {
    icon = "",
    name = "Copilot CLI",
    active = function()
      return terminal_visible(function(cmd) return cmd ~= nil and cmd:find("^copilot") ~= nil end)
    end,
    run = function()
      leave_bar()
      feed("<leader>ap") -- lua/plugins/copilot-cli.lua
    end,
  },
  {
    icon = "",
    name = "Terminal",
    active = function()
      return terminal_visible(function(cmd) return cmd == nil end)
    end,
    run = function()
      leave_bar()
      feed("<A-t>") -- lua/plugins/terminal.lua
    end,
  },
  {
    icon = "",
    name = "Plugins",
    bottom = true,
    run = function() require("lazy").show() end,
  },
}

local ns = vim.api.nvim_create_namespace(FT)
local buf ---@type integer?
local lines = {} ---@type table<integer, activitybar.Item>
M.enabled = false

---@return integer?
local function win()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(w) == buf then
      return w
    end
  end
end

function M.render()
  local w = win()
  if not w then
    return
  end
  local top, bottom = {}, {}
  for _, item in ipairs(M.items) do
    table.insert(item.bottom and bottom or top, item)
  end

  local text, map = {}, {}
  local function add(item)
    text[#text + 1] = ""
    -- the trailing spaces give the icon room to be drawn two cells wide
    -- (ghostty/config maps these codepoints to a full-size icon font)
    text[#text + 1] = "  " .. item.icon .. "  "
    map[#text] = item
  end
  for _, item in ipairs(top) do
    add(item)
  end
  -- push the bottom group down to the window's last rows
  local height = vim.api.nvim_win_get_height(w)
  while #text < height - #bottom * 2 do
    text[#text + 1] = ""
  end
  for _, item in ipairs(bottom) do
    add(item)
  end
  lines = map

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for lnum, item in pairs(map) do
    local ok, on = pcall(item.active or function() return false end)
    on = ok and on
    vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, 0, {
      end_col = #text[lnum],
      hl_group = on and "ActivityBarActive" or "ActivityBarIcon",
      virt_text = on and { { "▎", "ActivityBarIndicator" } } or nil,
      virt_text_pos = "overlay",
    })
  end
end

local function item_at_cursor()
  return lines[vim.api.nvim_win_get_cursor(0)[1]]
end

function M.activate()
  local item = item_at_cursor()
  if item then
    item.run()
    vim.defer_fn(M.refresh, 50)
  end
end

-- j/k hop between icons rather than over the blank rows.
---@param dir 1|-1
local function step(dir)
  local lnum, last = vim.api.nvim_win_get_cursor(0)[1], vim.api.nvim_buf_line_count(0)
  local l = lnum + dir
  while l >= 1 and l <= last do
    if lines[l] then
      vim.api.nvim_win_set_cursor(0, { l, 0 })
      return
    end
    l = l + dir
  end
end

local function create_buf()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = FT
  vim.bo[buf].bufhidden = "hide"
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, desc = desc })
  end
  map("<LeftRelease>", M.activate, "Open panel")
  map("<CR>", M.activate, "Open panel")
  map("l", M.activate, "Open panel")
  map("j", function() step(1) end, "Next icon")
  map("k", function() step(-1) end, "Previous icon")
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      local item = item_at_cursor()
      vim.api.nvim_echo({ { item and item.name or "" } }, false, {})
    end,
  })
end

-- Keep the bar at the far left edge, full height, WIDTH wide.
function M.pin()
  local w = win()
  if not w then
    return
  end
  if vim.fn.win_screenpos(w)[2] ~= 1 or vim.api.nvim_win_get_height(w) < vim.o.lines - vim.o.cmdheight - 2 then
    -- without this, 'equalalways' re-evens every other window as the bar moves
    local ea = vim.o.equalalways
    vim.o.equalalways = false
    vim.api.nvim_win_call(w, function()
      vim.cmd("wincmd H")
    end)
    vim.o.equalalways = ea
  end
  if vim.api.nvim_win_get_width(w) ~= WIDTH then
    vim.api.nvim_win_set_width(w, WIDTH)
  end
end

function M.open()
  M.enabled = true
  if win() then
    return M.pin()
  end
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    create_buf()
  end
  local w = vim.api.nvim_open_win(buf, false, { split = "left", win = -1, width = WIDTH })
  local wo = vim.wo[w]
  wo.winfixwidth = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.statuscolumn = ""
  wo.foldcolumn = "0"
  wo.cursorline = false
  wo.wrap = false
  wo.list = false -- LazyVim turns it on; it would draw the icons' trailing spaces as "-"
  wo.winbar = ""
  wo.fillchars = "eob: "
  wo.winhighlight = "Normal:ActivityBar,NormalNC:ActivityBar"
  M.pin()
  M.render()
end

function M.close()
  M.enabled = false
  local w = win()
  if w and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.api.nvim_win_close(w, true)
  end
end

function M.toggle()
  if win() then
    M.close()
  else
    M.open()
  end
end

---@param a integer
---@param b integer
---@param t number share of `a`
local function blend(a, b, t)
  local ret = 0
  for shift = 16, 0, -8 do
    local ca, cb = bit.band(bit.rshift(a, shift), 0xff), bit.band(bit.rshift(b, shift), 0xff)
    ret = ret + bit.lshift(math.floor(ca * t + cb * (1 - t) + 0.5), shift)
  end
  return ret
end

local function highlights()
  local sidebar = vim.fn.hlexists("NormalSB") == 1 and "NormalSB" or "NormalFloat"
  vim.api.nvim_set_hl(0, "ActivityBar", { link = sidebar, default = true })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local bg = vim.api.nvim_get_hl(0, { name = sidebar, link = false }).bg or normal.bg
  local fg = normal.fg
  local accent = vim.api.nvim_get_hl(0, { name = "Directory", link = false }).fg
  if fg and bg then
    -- inactive icons: most of the way to the text colour, so they read clearly
    -- but still step back from the lit one
    vim.api.nvim_set_hl(0, "ActivityBarIcon", { fg = blend(fg, bg, 0.75), default = true })
    vim.api.nvim_set_hl(0, "ActivityBarActive", { fg = accent or fg, bold = true, default = true })
    vim.api.nvim_set_hl(0, "ActivityBarIndicator", { fg = accent or fg, default = true })
  else
    vim.api.nvim_set_hl(0, "ActivityBarIcon", { link = "Normal", default = true })
    vim.api.nvim_set_hl(0, "ActivityBarActive", { link = "Title", default = true })
    vim.api.nvim_set_hl(0, "ActivityBarIndicator", { link = "Special", default = true })
  end
end

function M.setup()
  highlights()
  local group = vim.api.nvim_create_augroup(FT, { clear = true })
  local pending = false
  local function refresh()
    if pending or not M.enabled then
      return
    end
    pending = true
    vim.schedule(function()
      pending = false
      if not win() then
        -- a new tab gets its own bar; a bar closed with :q / <C-w>o stays closed
        if vim.fn.tabpagenr() ~= M.tab then
          M.tab = vim.fn.tabpagenr()
          M.open()
        end
        return
      end
      M.pin()
      M.render()
    end)
  end
  M.refresh = refresh
  vim.api.nvim_create_autocmd({ "WinNew", "WinClosed", "BufWinEnter", "WinResized", "VimResized", "TermClose" }, {
    group = group,
    callback = refresh,
  })
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      M.tab = nil
      refresh()
    end,
  })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })
  -- Don't let the bar keep nvim open: when the last editor window goes, it goes.
  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    callback = function()
      local closing = vim.api.nvim_get_current_win()
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
        if w ~= closing and vim.api.nvim_win_get_config(w).relative == "" and ft ~= FT and not ft:find("^snacks_") then
          return
        end
      end
      local w = win()
      if w then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end,
  })
  -- Sessions would restore the bar as an empty window; leave it out of them.
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceSavePre",
    callback = function()
      local w = win()
      if w then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceLoadPost",
    callback = function()
      if M.enabled then
        M.open()
      end
    end,
  })
  -- Opening a split during startup closes the dashboard and the explorer that
  -- `nvim <dir>` opens, so wait until they have settled.
  local function start()
    vim.defer_fn(function()
      M.tab = vim.fn.tabpagenr()
      M.open()
    end, 100)
  end
  if #vim.api.nvim_list_uis() > 0 then
    start()
  else
    vim.api.nvim_create_autocmd("UIEnter", { group = group, once = true, callback = start })
  end
end

return M
