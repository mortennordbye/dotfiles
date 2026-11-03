-- Keybinding cheatsheet, built into nvim. The content is lua/config/cheatsheet_data.lua.
--
-- <leader>h (or the keyboard icon in the activity bar) opens the sheet: a card
-- per section, laid out in columns like the old HTML page, keys in their own
-- column and notes in grey. In it, `s` opens a fuzzy search across every row,
-- whose preview shows the row's whole section. ★ marks keys this config adds
-- or changes.

local M = {}

local SECTION_W = 10 -- the section chip column in the list
local KEYS_W = 16 -- the keys column, in the list and the preview

---@param s string
---@param w integer
local function pad(s, w)
  return s .. string.rep(" ", math.max(1, w - vim.api.nvim_strwidth(s)))
end

-- One section as preview text: title, then its rows under their sub-headings.
---@return string text, table[] extmarks, table<table, integer> row_line row -> line
local function render_section(sec)
  local lines, marks, row_line = {}, {}, {}
  local function add(text, hl, col)
    lines[#lines + 1] = text
    if hl then
      marks[#marks + 1] = { row = #lines, col = col or 0, end_col = #text, hl_group = hl }
    end
  end
  add((sec.title or sec.name) .. (sec.about and ("  (" .. sec.about .. ")") or ""), "Title")
  add("")
  for _, row in ipairs(sec) do
    if row.group then
      add("")
      add(row.group, "Special")
    else
      local keys = pad(row[1], KEYS_W)
      local line = "  " .. keys .. row[2] .. (row.custom and "  ★" or "")
      add(line)
      marks[#marks + 1] = { row = #lines, col = 2, end_col = 2 + #keys, hl_group = "SnacksPickerSpecial" }
      if row.custom then
        marks[#marks + 1] = { row = #lines, col = #line - #"★", end_col = #line, hl_group = "DiagnosticWarn" }
      end
      row_line[row] = #lines
      if row.note then
        add(string.rep(" ", 2 + KEYS_W) .. row.note, "Comment")
      end
    end
  end
  return table.concat(lines, "\n"), marks, row_line
end

local function items()
  -- re-read each time, so edits to the data file show up without a restart
  package.loaded["config.cheatsheet_data"] = nil
  local ret = {}
  for _, sec in ipairs(require("config.cheatsheet_data")) do
    local text, marks, row_line = render_section(sec)
    local group
    for _, row in ipairs(sec) do
      if row.group then
        group = row.group
      else
        ret[#ret + 1] = {
          text = table.concat(
            { sec.name, sec.title or "", group or "", row[1], row[2], row.note or "", row.kw or "" },
            " "
          ),
          section = sec.name,
          keys = row[1],
          desc = row[2],
          note = row.note,
          custom = row.custom,
          preview = { text = text, extmarks = marks },
          pos = { row_line[row], 0 },
        }
      end
    end
  end
  return ret
end

---@type snacks.picker.format
local function format(item)
  local ret = {
    { pad(item.section, SECTION_W), "SnacksPickerLabel" },
    { pad(item.keys, KEYS_W), "SnacksPickerSpecial" },
    { item.desc },
  }
  if item.note then
    ret[#ret + 1] = { "  " .. item.note, "SnacksPickerComment" }
  end
  if item.custom then
    ret[#ret + 1] = { "  ★", "DiagnosticWarn" }
  end
  return ret
end

--- Fuzzy search across every row (`s` in the sheet).
function M.search()
  Snacks.picker({
    title = "Cheatsheet search  (★ = this config)",
    items = items(),
    format = format,
    preview = "preview",
    matcher = { sort_empty = false }, -- keep the sheet's own order until you type
    sort = { fields = { "score:desc", "idx" } },
    layout = { preset = "default" },
    confirm = "close",
  })
end

-- ── The sheet ──────────────────────────────────────────────────────────────
-- Laid out like the old HTML page: every section is a card with a title, its
-- sub-headings and rows; keys in their own column, notes in grey under the
-- description. Cards flow into as many columns as the window fits.

local CARD_MIN = 62 -- narrowest a card may get, borders included
local CARD_MAX = 100 -- widest, so a lone column still reads comfortably
local GAP = 2 -- space between card columns
local sheet = {} ---@type {buf?: integer, win?: snacks.win, cards?: {name: string, line: integer, col: integer}[]}

---@param text string
---@param width integer
---@return string[]
local function wrap(text, width)
  local lines, cur = {}, ""
  for word in text:gmatch("%S+") do
    local try = cur == "" and word or (cur .. " " .. word)
    if vim.api.nvim_strwidth(try) > width and cur ~= "" then
      lines[#lines + 1] = cur
      cur = word
    else
      cur = try
    end
  end
  lines[#lines + 1] = cur
  return lines
end

---@alias cheatsheet.Seg {[1]: string, [2]: string?}
---@alias cheatsheet.Line cheatsheet.Seg[]

-- One section as a bordered card of `width` display cells.
---@return cheatsheet.Line[]
local function card(sec, width)
  local inner = width - 4 -- "│ " … " │"
  local text_w = inner - KEYS_W
  local out = {} ---@type cheatsheet.Line[]
  local function line(segs)
    local used = 0
    for _, seg in ipairs(segs) do
      used = used + vim.api.nvim_strwidth(seg[1])
    end
    local l = { { "│ ", "CheatsheetBorder" } }
    vim.list_extend(l, segs)
    l[#l + 1] = { string.rep(" ", math.max(0, inner - used)) .. " │", "CheatsheetBorder" }
    out[#out + 1] = l
  end

  local title = " " .. (sec.title or sec.name) .. " "
  local about = sec.about and ("(" .. sec.about .. ") ") or ""
  local fill = width - 3 - vim.api.nvim_strwidth(title) - vim.api.nvim_strwidth(about)
  out[1] = {
    { "╭─", "CheatsheetBorder" },
    { title, "CheatsheetTitle" },
    { about, "CheatsheetNote" },
    { string.rep("─", math.max(0, fill)) .. "╮", "CheatsheetBorder" },
  }
  local first = true
  for _, row in ipairs(sec) do
    if row.group then
      if not first then
        line({})
      end
      line({ { row.group, "CheatsheetGroup" } })
    else
      local star = row.custom and " ★" or ""
      local desc = wrap(row[2], text_w - vim.api.nvim_strwidth(star))
      local keys = row[1]
      if vim.api.nvim_strwidth(keys) >= KEYS_W then
        -- long key text gets its own line
        line({ { keys, "CheatsheetKeys" } })
        keys = ""
      end
      for i, d in ipairs(desc) do
        local segs = { { pad(i == 1 and keys or "", KEYS_W), "CheatsheetKeys" }, { d, "CheatsheetDesc" } }
        if i == 1 and row.custom then
          segs[#segs + 1] = { star, "CheatsheetCustom" }
        end
        line(segs)
      end
      if row.note then
        for _, n in ipairs(wrap(row.note, text_w)) do
          line({ { string.rep(" ", KEYS_W) }, { n, "CheatsheetNote" } })
        end
      end
    end
    first = false
  end
  out[#out + 1] = { { "╰" .. string.rep("─", width - 2) .. "╯", "CheatsheetBorder" } }
  return out
end

local ns = vim.api.nvim_create_namespace("cheatsheet")

local function render()
  local buf, win = sheet.buf, sheet.win and sheet.win.win
  if not (buf and win and vim.api.nvim_win_is_valid(win)) then
    return
  end
  package.loaded["config.cheatsheet_data"] = nil
  local data = require("config.cheatsheet_data")
  local total = vim.api.nvim_win_get_width(win) - 2
  local ncols = math.max(1, math.floor((total + GAP) / (CARD_MIN + GAP)))
  local width = math.min(CARD_MAX, math.floor((total - GAP * (ncols - 1)) / ncols))

  -- header: what the page is and how to move around it
  local header = {
    {
      { "  LazyVim cheatsheet", "CheatsheetTitle" },
      { "   ★ = a key this config adds or changes", "CheatsheetNote" },
    },
    {
      { "  " },
      { "/", "CheatsheetKeys" },
      { " find on the page   ", "CheatsheetNote" },
      { "s", "CheatsheetKeys" },
      { " fuzzy search   ", "CheatsheetNote" },
      { "Tab", "CheatsheetKeys" },
      { " / ", "CheatsheetNote" },
      { "S-Tab", "CheatsheetKeys" },
      { " next / previous section   ", "CheatsheetNote" },
      { "gs", "CheatsheetKeys" },
      { " go to section   ", "CheatsheetNote" },
      { "q", "CheatsheetKeys" },
      { " close", "CheatsheetNote" },
    },
    {},
  }

  -- masonry: each card goes into the currently shortest column
  local cols = {} ---@type cheatsheet.Line[][]
  local placed = {} ---@type {name: string, col: integer, row: integer}[]
  for i = 1, ncols do
    cols[i] = {}
  end
  for _, sec in ipairs(data) do
    local best = 1
    for i = 2, ncols do
      if #cols[i] < #cols[best] then
        best = i
      end
    end
    placed[#placed + 1] = { name = sec.name, col = best, row = #cols[best] + 1 }
    vim.list_extend(cols[best], card(sec, width))
    table.insert(cols[best], {})
  end
  local height = 0
  for i = 1, ncols do
    height = math.max(height, #cols[i])
  end

  local lines, marks = {}, {}
  local function emit(segs_per_col)
    local text = ""
    for c, segs in ipairs(segs_per_col) do
      local used = 0
      for _, seg in ipairs(segs) do
        if seg[2] then
          marks[#marks + 1] = { #lines, #text, #text + #seg[1], seg[2] }
        end
        text = text .. seg[1]
        used = used + vim.api.nvim_strwidth(seg[1])
      end
      if c < #segs_per_col then
        text = text .. string.rep(" ", width - used + GAP)
      end
    end
    lines[#lines + 1] = (" " .. text):gsub("%s+$", "")
    -- the leading margin shifts every mark by one byte
    for i = #marks, 1, -1 do
      if marks[i][1] ~= #lines - 1 then
        break
      end
      marks[i][2], marks[i][3] = marks[i][2] + 1, marks[i][3] + 1
    end
  end
  for _, h in ipairs(header) do
    emit({ h })
  end
  local top = #lines
  for r = 1, height do
    local row = {}
    for c = 1, ncols do
      row[c] = cols[c][r] or {}
    end
    emit(row)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end

  -- where each card's title is, for Tab / S-Tab / g (in reading order)
  sheet.cards = {}
  for _, p in ipairs(placed) do
    sheet.cards[#sheet.cards + 1] = {
      name = p.name,
      line = top + p.row,
      col = 1 + (p.col - 1) * (width + GAP) + 3, -- display column of the title text
    }
  end
  table.sort(sheet.cards, function(a, b)
    return a.line == b.line and a.col < b.col or a.line < b.line
  end)
end

---@param card {line: integer, col: integer}
local function goto_card(c)
  local win = sheet.win.win
  vim.api.nvim_win_set_cursor(win, { c.line, 0 })
  vim.api.nvim_win_call(win, function()
    vim.cmd("normal! " .. c.col .. "|")
    vim.cmd("normal! zt")
  end)
end

---@param dir 1|-1
local function step(dir)
  local cur = vim.api.nvim_win_get_cursor(0)
  local col = vim.fn.virtcol(".")
  local list = sheet.cards
  local from = dir == 1 and 1 or #list
  local to = dir == 1 and #list or 1
  for i = from, to, dir do
    local c = list[i]
    local after = c.line > cur[1] or (c.line == cur[1] and c.col > col)
    local before = c.line < cur[1] or (c.line == cur[1] and c.col < col)
    if (dir == 1 and after) or (dir == -1 and before) then
      return goto_card(c)
    end
  end
  goto_card(list[dir == 1 and 1 or #list]) -- wrap around
end

local function highlights()
  local set = function(name, link)
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  set("CheatsheetBorder", "FloatBorder")
  set("CheatsheetTitle", "Title")
  set("CheatsheetGroup", "Special")
  set("CheatsheetKeys", "Function")
  set("CheatsheetDesc", "Normal")
  set("CheatsheetNote", "Comment")
  set("CheatsheetCustom", "DiagnosticWarn")
end

function M.open()
  highlights()
  if sheet.win and sheet.win:valid() then
    return sheet.win:focus()
  end
  sheet.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[sheet.buf].filetype = "cheatsheet"
  sheet.win = Snacks.win({
    buf = sheet.buf,
    width = 0.94,
    height = 0.92,
    border = "rounded",
    title = " Cheatsheet ",
    title_pos = "center",
    wo = {
      wrap = false,
      list = false,
      number = false,
      relativenumber = false,
      signcolumn = "no",
      statuscolumn = "",
      cursorline = false,
      sidescrolloff = 0,
      winhighlight = "NormalFloat:Normal",
    },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
      s = {
        function()
          sheet.win:close()
          M.search()
        end,
        desc = "Fuzzy search",
      },
      ["<Tab>"] = {
        function()
          step(1)
        end,
        desc = "Next section",
      },
      ["<S-Tab>"] = {
        function()
          step(-1)
        end,
        desc = "Previous section",
      },
      gs = {
        function()
          vim.ui.select(sheet.cards, {
            prompt = "Go to section",
            format_item = function(c)
              return c.name
            end,
          }, function(c)
            if c then
              goto_card(c)
            end
          end)
        end,
        desc = "Go to section",
      },
    },
    on_win = function()
      vim.schedule(render)
    end,
  })
  local group = vim.api.nvim_create_augroup("cheatsheet", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      vim.schedule(render)
    end,
  })
  render()
end

return M
