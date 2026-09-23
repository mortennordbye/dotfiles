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

-- A window focus can go back to: a plain split, not the bar, a float, or the
-- empty frame window a snacks sidebar sits in.
---@param w integer
local function usable(w)
  if not vim.api.nvim_win_is_valid(w) or vim.api.nvim_win_get_config(w).relative ~= "" then
    return false
  end
  local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
  return ft ~= FT and ft ~= "snacks_layout_box"
end

-- Hand focus back to an editor window, so commands that act on "the current
-- project" (LazyVim.root) see a real buffer rather than the bar.
---@param no_term? boolean skip terminals: entering one switches it to terminal
---   mode, and a picker opened from there starts in normal mode, not insert
local function leave_bar(no_term)
  if vim.bo.filetype ~= FT then
    return
  end
  local function ok(w)
    return usable(w) and not (no_term and vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "terminal")
  end
  local prev = vim.fn.win_getid(vim.fn.winnr("#"))
  if prev ~= 0 and ok(prev) then
    return vim.api.nvim_set_current_win(prev)
  end
  -- prefer a file window, then anything else (dashboard, a terminal)
  local fallback
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if ok(w) then
      if vim.bo[vim.api.nvim_win_get_buf(w)].buftype == "" then
        return vim.api.nvim_set_current_win(w)
      end
      fallback = fallback or w
    end
  end
  if fallback then
    vim.api.nvim_set_current_win(fallback)
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

---@param ft string
local function filetype_visible(ft)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then
      return true
    end
  end
  return false
end

-- Run the function behind a normal-mode mapping defined elsewhere. Calling it
-- rather than feeding the keys matters when focus lands in a terminal, where
-- fed keys would be typed into the program running there.
local function run_map(lhs)
  local m = vim.fn.maparg(lhs, "n", false, true)
  if m.callback then
    m.callback()
  elseif m.rhs then
    vim.api.nvim_feedkeys(vim.keycode(m.rhs), m.noremap == 1 and "n" or "m", false)
  end
end

---@class activitybar.Item
---@field icon string
---@field name string
---@field run fun()
---@field active? fun(): boolean
---@field badge? fun(): integer? count drawn at the icon's lower right, like VSCode
---@field bottom? boolean
---@field optional? "on"|"off" can be hidden with Space u X (or the gear menu); the value is the default

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
      leave_bar(true)
      Snacks.picker.grep({ cwd = LazyVim.root() })
    end,
  },
  {
    icon = "",
    name = "Source Control",
    active = function() return sidebar(true) ~= nil end,
    badge = function() return M.changes end,
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
    icon = "\u{eb91}", -- codicon debug-alt
    name = "Run and Debug",
    optional = "off",
    -- lit while a debug session runs; the dap.core extra opens its panels then
    active = function()
      return package.loaded["dap"] ~= nil and require("dap").session() ~= nil
    end,
    run = function()
      leave_bar(true)
      if package.loaded["dap"] and require("dap").session() then
        require("dapui").toggle()
      else
        -- asks which launch configuration to use, like VSCode's F5
        require("dap").continue()
      end
    end,
  },
  {
    icon = "\u{ea79}", -- codicon beaker
    name = "Testing",
    optional = "off",
    active = function()
      return filetype_visible("neotest-summary")
    end,
    badge = function() return M.failed_tests end,
    run = function()
      leave_bar(true)
      require("neotest").summary.toggle()
    end,
  },
  {
    icon = "\u{ea6c}", -- codicon warning
    name = "Problems",
    optional = "off",
    active = function()
      return package.loaded["trouble"] ~= nil and require("trouble").is_open("diagnostics")
    end,
    -- errors only, like the red count in VSCode's status bar; warnings are
    -- too often noise to be worth a badge
    badge = function()
      return vim.diagnostic.count(nil, { severity = vim.diagnostic.severity.ERROR })[vim.diagnostic.severity.ERROR]
    end,
    run = function()
      leave_bar(true)
      vim.cmd("Trouble diagnostics toggle")
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
      run_map("<leader>ap") -- lua/plugins/copilot-cli.lua
    end,
  },
  {
    icon = "\u{eb44}", -- codicon rocket
    name = "Antigravity CLI",
    optional = "on",
    active = function()
      return terminal_visible(function(cmd) return cmd ~= nil and cmd:find("^agy") ~= nil end)
    end,
    run = function()
      leave_bar()
      run_map("<leader>ag") -- lua/plugins/antigravity-cli.lua
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
      run_map("<A-t>") -- lua/plugins/terminal.lua
    end,
  },
  {
    icon = "",
    name = "Cheatsheet",
    bottom = true,
    run = function()
      leave_bar(true)
      require("config.cheatsheet").open()
    end,
  },
  {
    icon = "",
    name = "Plugins",
    bottom = true,
    run = function() require("lazy").show() end,
  },
  {
    icon = "\u{eb51}",
    name = "Settings",
    bottom = true,
    run = function()
      leave_bar(true)
      M.settings()
    end,
  },
}

-- Optional icons (see activitybar.Item.optional). Which ones are shown is
-- kept in a file so it survives restarts; icons not in it use their default.
local shown_file = vim.fn.stdpath("state") .. "/activitybar.json"
local shown ---@type table<string, boolean>

---@param item activitybar.Item
---@return boolean
function M.visible(item)
  if not item.optional then
    return true
  end
  if not shown then
    local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(shown_file), "\n")) end)
    shown = ok and type(data) == "table" and data or {}
  end
  if shown[item.name] == nil then
    return item.optional == "on"
  end
  return shown[item.name]
end

-- Tick which optional icons to show. Picking one flips it and reopens the
-- list, so several can be changed in a row; Esc closes it.
function M.choose_icons()
  local items = vim.tbl_filter(function(it) return it.optional ~= nil end, M.items)
  vim.ui.select(items, {
    prompt = "Activity bar icons",
    format_item = function(it)
      return (M.visible(it) and "[x] " or "[ ] ") .. it.name
    end,
  }, function(it)
    if not it then
      return
    end
    shown[it.name] = not M.visible(it)
    pcall(vim.fn.writefile, { vim.json.encode(shown) }, shown_file)
    M.render()
    vim.schedule(M.choose_icons)
  end)
end

-- The gear's menu, like VSCode's Manage button: the places settings live.
M.settings_menu = {
  { "Config files", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end },
  { "Search config (grep)", function() Snacks.picker.grep({ cwd = vim.fn.stdpath("config") }) end },
  { "LazyVim extras (feature bundles)", function() vim.cmd("LazyExtras") end },
  { "Language servers & tools (Mason)", function() vim.cmd("Mason") end },
  { "Colour scheme", function() Snacks.picker.colorschemes() end },
  { "Toggle options (wrap, spell, diagnostics, ...)", function()
    require("which-key").show({ keys = "<leader>u", loop = true })
  end },
  { "Keymaps", function() Snacks.picker.keymaps() end },
  { "Cheatsheet", function() require("config.cheatsheet").open() end },
  { "Choose activity bar icons (Antigravity, Debug, Testing, Problems)", function() M.choose_icons() end },
  { "Health check", function() vim.cmd("checkhealth") end },
  { "Restart Neovim (reload config)", function() run_map("<leader>qr") end }, -- lua/config/keymaps.lua
}

function M.settings()
  vim.ui.select(M.settings_menu, {
    prompt = "Settings",
    format_item = function(item) return item[1] end,
  }, function(item)
    if item then
      item[2]()
    end
  end)
end

-- Failed tests, for the Testing badge. neotest reports only the tests each
-- run touched, so keep every test's last status and count the failures.
M.failed_tests = nil ---@type integer?
local test_status = {} ---@type table<string, string>

-- A neotest consumer, registered in lua/plugins/test.lua.
---@param client neotest.Client
function M.neotest_consumer(client)
  client.listeners.results = function(adapter_id, results, partial)
    if partial then
      return
    end
    local tree = client:get_position(nil, { adapter = adapter_id })
    for id, result in pairs(results) do
      -- the file and any class holding a failed test are "failed" too;
      -- count the tests themselves
      local node = tree and tree:get_key(id)
      if node and node:data().type == "test" then
        test_status[id] = result.status
      end
    end
    local failed = 0
    for _, status in pairs(test_status) do
      failed = failed + (status == "failed" and 1 or 0)
    end
    M.failed_tests = failed
    if M.refresh then
      M.refresh()
    end
  end
  return {}
end

-- Changed files across the project's repos, for the Source Control badge.
-- Counted in the background; the badge shows the last answer.
M.changes = nil ---@type integer?
local counting = false
function M.count_changes()
  if counting then
    return
  end
  local p = sidebar(false) or sidebar(true)
  local cwd = p and p:cwd() or LazyVim.root()
  local root = Snacks.git.get_root(cwd)
  local repos = root and { root } or require("config.explorer_git").nested_repos(cwd)
  local total, left = 0, #repos
  local function done()
    counting = false
    total = #repos > 0 and total or nil
    if M.changes ~= total then
      M.changes = total
      M.render()
    end
  end
  counting = true
  if left == 0 then
    return done()
  end
  for _, repo in ipairs(repos) do
    vim.system({ "git", "--no-optional-locks", "status", "--porcelain", "-unormal" }, { cwd = repo }, function(res)
      if res.code == 0 then
        total = total + #vim.split(vim.trim(res.stdout or ""), "\n", { trimempty = true })
      end
      left = left - 1
      if left == 0 then
        vim.schedule(done)
      end
    end)
  end
end

local ns = vim.api.nvim_create_namespace(FT)
local buf ---@type integer?
local lines = {} ---@type table<integer, activitybar.Item> icon rows
local badges = {} ---@type table<integer, activitybar.Item> badge rows, clickable too
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
    if M.visible(item) then
      table.insert(item.bottom and bottom or top, item)
    end
  end

  local text, map, marks, badge_rows = {}, {}, {}, {}
  local function add(item)
    text[#text + 1] = ""
    -- the trailing spaces give the icon room to be drawn two cells wide
    -- (ghostty/config maps these codepoints to a full-size icon font)
    text[#text + 1] = "  " .. item.icon .. "  "
    map[#text] = item
    local ok, on = pcall(item.active or function() return false end)
    marks[#marks + 1] = {
      #text - 1,
      0,
      {
        end_col = #text[#text],
        hl_group = ok and on and "ActivityBarActive" or "ActivityBarIcon",
        virt_text = ok and on and { { "▎", "ActivityBarIndicator" } } or nil,
        virt_text_pos = "overlay",
      },
    }
  end
  -- A badge goes on the spacer row under its icon, ending under the icon's
  -- right half (the icon is drawn over columns 2-3) so the pill sits at its
  -- lower-right corner the way VSCode draws it. Ending in the last column
  -- instead pushed it against the window separator, where it got clipped.
  local function badge(item, row)
    local ok, n = pcall(item.badge or function() end)
    if not (ok and type(n) == "number" and n > 0) then
      return
    end
    local label = n > 99 and "99+" or tostring(n)
    local col = math.max(0, WIDTH - 1 - vim.api.nvim_strwidth(label))
    text[row] = string.rep(" ", col) .. label
    badge_rows[row] = item
    marks[#marks + 1] = { row - 1, col, { end_col = #text[row], hl_group = "ActivityBarBadge" } }
  end
  for _, item in ipairs(top) do
    add(item)
    if item.badge then
      -- its own row under the icon, plus the usual gap before the next one,
      -- so the count can't be read as belonging to the icon below
      text[#text + 1] = ""
      badge(item, #text)
    end
  end
  -- push the bottom group down to the window's last rows, keeping one blank
  -- row under it: the icon font draws taller than a cell, and on the very
  -- last row the statusline cut the glyph in half
  local height = vim.api.nvim_win_get_height(w)
  while #text < height - #bottom * 2 - 1 do
    text[#text + 1] = ""
  end
  for _, item in ipairs(bottom) do
    add(item)
  end
  lines, badges = map, badge_rows

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], m[3])
  end
end

local function item_at_cursor()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  return lines[row] or badges[row]
end

function M.activate()
  local item = item_at_cursor()
  if item then
    item.run()
    vim.defer_fn(M.refresh, 50)
  end
  -- closing a panel, or a click between icons, leaves nothing new to focus;
  -- don't stay in the bar
  leave_bar()
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
  -- nothing to scroll or select here: without these the wheel shifts the
  -- icons off their rows and a drag starts Visual mode
  for _, lhs in ipairs({
    "<LeftDrag>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
    "<ScrollWheelUp>", "<ScrollWheelDown>", "<ScrollWheelLeft>", "<ScrollWheelRight>",
  }) do
    vim.keymap.set({ "n", "v" }, lhs, "<Nop>", { buffer = buf })
  end
  map("j", function() step(1) end, "Next icon")
  map("k", function() step(-1) end, "Previous icon")
  -- No cursor in the bar. It sat on an icon, where the terminal redraws the
  -- two-cell glyph as one cell and the icon visibly jumps; and arriving from
  -- a terminal could leave it in insert mode, showing a thin line.
  local guicursor ---@type string?
  vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    buffer = buf,
    callback = function()
      -- only when actually inserting: stopinsert takes effect once the
      -- current key is done, so an unneeded one would also knock the panel
      -- the click opens (the grep picker) out of insert mode
      if vim.fn.mode():find("^[iRt]") then
        vim.cmd("stopinsert")
      end
      if not guicursor then
        guicursor = vim.o.guicursor
        vim.o.guicursor = "a:ActivityBarCursor"
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    buffer = buf,
    callback = function()
      if guicursor then
        vim.o.guicursor = guicursor
        guicursor = nil
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    buffer = buf,
    callback = function()
      vim.schedule(function() vim.cmd("stopinsert") end)
    end,
  })
  -- nothing to select here, however Visual mode got started
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = "*:[vV\22]*",
    callback = function()
      if vim.api.nvim_get_current_buf() == buf then
        vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
      end
    end,
  })
  for _, lhs in ipairs({ "v", "V", "<C-v>" }) do
    vim.keymap.set("n", lhs, "<Nop>", { buffer = buf })
  end
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      -- stay in column 0, so the view can never be pushed sideways
      if vim.fn.col(".") ~= 1 then
        vim.api.nvim_win_set_cursor(0, { vim.fn.line("."), 0 })
      end
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
  wo.winfixbuf = true -- keep :e, <C-o>, buffer switches from loading files into the bar
  wo.scrolloff = 0
  wo.sidescrolloff = 0 -- LazyVim's 8 scrolled the bar sideways, out of view
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
  -- blend=100 makes nvim hide the terminal cursor while it uses this group
  vim.api.nvim_set_hl(0, "ActivityBarCursor", { blend = 100, nocombine = true })
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
    vim.api.nvim_set_hl(0, "ActivityBarBadge", { fg = bg, bg = accent or fg, bold = true, default = true })
  else
    vim.api.nvim_set_hl(0, "ActivityBarBadge", { link = "PmenuSel", default = true })
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
        -- closed by :q, <C-w>o, a session load, or a new tab without one:
        -- bring it back. Only <leader>uA (M.close) turns it off.
        return M.open()
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
  vim.api.nvim_create_autocmd("TabEnter", { group = group, callback = refresh })
  -- the Problems badge; refresh() batches the bursts an LSP sends
  vim.api.nvim_create_autocmd("DiagnosticChanged", { group = group, callback = refresh })
  -- The Source Control badge: recount when files are saved, nvim regains
  -- focus or the folder changes, and on a slow timer for changes made
  -- elsewhere (e.g. by Claude).
  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "DirChanged" }, {
    group = group,
    callback = function()
      if M.enabled then
        M.count_changes()
      end
    end,
  })
  local timer = assert(vim.uv.new_timer())
  timer:start(5000, 5000, vim.schedule_wrap(function()
    if M.enabled and win() then
      M.count_changes()
    end
  end))
  -- the wheel over an unfocused window scrolls it without the buffer's maps
  vim.api.nvim_create_autocmd("WinScrolled", {
    group = group,
    callback = vim.schedule_wrap(function()
      -- scheduled: a fast wheel queues several scrolls, and resetting after
      -- the first one lets the rest through unseen
      local w = win()
      if w then
        vim.api.nvim_win_call(w, function()
          local view = vim.fn.winsaveview()
          if view.topline ~= 1 or view.leftcol ~= 0 then
            vim.fn.winrestview({ topline = 1, leftcol = 0 })
          end
        end)
      end
    end),
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
      M.open()
      M.count_changes()
    end, 100)
  end
  if #vim.api.nvim_list_uis() > 0 then
    start()
  else
    vim.api.nvim_create_autocmd("UIEnter", { group = group, once = true, callback = start })
  end
end

return M
