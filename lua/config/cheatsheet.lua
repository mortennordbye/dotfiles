-- Keybinding cheatsheet, built into nvim. The content is lua/config/cheatsheet_data.lua.
--
-- Opens as a picker: every row of the sheet is one line, and typing filters on
-- the keys, the description, the section and extra keywords. The preview shows
-- the whole section the row belongs to, with the row highlighted, so related
-- keys are seen together. Rows marked ★ are ones this config adds or changes.
--
-- Open it with <leader>h or the keyboard icon in the activity bar.

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
          text = table.concat({ sec.name, sec.title or "", group or "", row[1], row[2], row.note or "", row.kw or "" }, " "),
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

function M.open()
  Snacks.picker({
    title = "Cheatsheet  (★ = this config)",
    items = items(),
    format = format,
    preview = "preview",
    matcher = { sort_empty = false }, -- keep the sheet's own order until you type
    sort = { fields = { "score:desc", "idx" } },
    layout = { preset = "default" },
    confirm = "close",
  })
end

return M
