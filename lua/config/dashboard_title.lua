-- Dashboard title: the name of the folder nvim was opened in, drawn big.
--
-- It scales with the window. Each step down is used only when the one above
-- does not fit:
--   1. ANSI Shadow, 6 lines, about 8 cells a letter (the old NEOVIM look)
--   2. a 3x5 pixel font drawn with half blocks, 3 lines, 4 cells a letter
--   3. the name as plain spaced capitals
-- Letters are capitals only, so "Homelab" shows as HOMELAB. A name with a
-- character the fonts don't have (anything but A-Z, 0-9, space, - _ .) skips
-- straight to plain text.
local M = {}

-- ANSI Shadow, generated once from the figlet font (xero/figlet-fonts) so
-- figlet isn't needed at runtime. The ╔╗╚╝ shadow glyphs only line up when the
-- letters are joined with no extra space between them.
-- stylua: ignore
local shadow = {
    [" "] = { "    ", "    ", "    ", "    ", "    ", "    " },
    A = { " █████╗ ", "██╔══██╗", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
    B = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██████╔╝", "╚═════╝ " },
    C = { " ██████╗", "██╔════╝", "██║     ", "██║     ", "╚██████╗", " ╚═════╝" },
    D = { "██████╗ ", "██╔══██╗", "██║  ██║", "██║  ██║", "██████╔╝", "╚═════╝ " },
    E = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "███████╗", "╚══════╝" },
    F = { "███████╗", "██╔════╝", "█████╗  ", "██╔══╝  ", "██║     ", "╚═╝     " },
    G = { " ██████╗ ", "██╔════╝ ", "██║  ███╗", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
    H = { "██╗  ██╗", "██║  ██║", "███████║", "██╔══██║", "██║  ██║", "╚═╝  ╚═╝" },
    I = { "██╗", "██║", "██║", "██║", "██║", "╚═╝" },
    J = { "     ██╗", "     ██║", "     ██║", "██   ██║", "╚█████╔╝", " ╚════╝ " },
    K = { "██╗  ██╗", "██║ ██╔╝", "█████╔╝ ", "██╔═██╗ ", "██║  ██╗", "╚═╝  ╚═╝" },
    L = { "██╗     ", "██║     ", "██║     ", "██║     ", "███████╗", "╚══════╝" },
    M = { "███╗   ███╗", "████╗ ████║", "██╔████╔██║", "██║╚██╔╝██║", "██║ ╚═╝ ██║", "╚═╝     ╚═╝" },
    N = { "███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝" },
    O = { " ██████╗ ", "██╔═══██╗", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
    P = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔═══╝ ", "██║     ", "╚═╝     " },
    Q = { " ██████╗ ", "██╔═══██╗", "██║   ██║", "██║▄▄ ██║", "╚██████╔╝", " ╚══▀▀═╝ " },
    R = { "██████╗ ", "██╔══██╗", "██████╔╝", "██╔══██╗", "██║  ██║", "╚═╝  ╚═╝" },
    S = { "███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝" },
    T = { "████████╗", "╚══██╔══╝", "   ██║   ", "   ██║   ", "   ██║   ", "   ╚═╝   " },
    U = { "██╗   ██╗", "██║   ██║", "██║   ██║", "██║   ██║", "╚██████╔╝", " ╚═════╝ " },
    V = { "██╗   ██╗", "██║   ██║", "██║   ██║", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚═══╝  " },
    W = { "██╗    ██╗", "██║    ██║", "██║ █╗ ██║", "██║███╗██║", "╚███╔███╔╝", " ╚══╝╚══╝ " },
    X = { "██╗  ██╗", "╚██╗██╔╝", " ╚███╔╝ ", " ██╔██╗ ", "██╔╝ ██╗", "╚═╝  ╚═╝" },
    Y = { "██╗   ██╗", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚██╔╝  ", "   ██║   ", "   ╚═╝   " },
    Z = { "███████╗", "╚══███╔╝", "  ███╔╝ ", " ███╔╝  ", "███████╗", "╚══════╝" },
    ["0"] = { " ██████╗ ", "██╔═████╗", "██║██╔██║", "████╔╝██║", "╚██████╔╝", " ╚═════╝ " },
    ["1"] = { " ██╗", "███║", "╚██║", " ██║", " ██║", " ╚═╝" },
    ["2"] = { "██████╗ ", "╚════██╗", " █████╔╝", "██╔═══╝ ", "███████╗", "╚══════╝" },
    ["3"] = { "██████╗ ", "╚════██╗", " █████╔╝", " ╚═══██╗", "██████╔╝", "╚═════╝ " },
    ["4"] = { "██╗  ██╗", "██║  ██║", "███████║", "╚════██║", "     ██║", "     ╚═╝" },
    ["5"] = { "███████╗", "██╔════╝", "███████╗", "╚════██║", "███████║", "╚══════╝" },
    ["6"] = { " ██████╗ ", "██╔════╝ ", "███████╗ ", "██╔═══██╗", "╚██████╔╝", " ╚═════╝ " },
    ["7"] = { "███████╗", "╚════██║", "    ██╔╝", "   ██╔╝ ", "   ██║  ", "   ╚═╝  " },
    ["8"] = { " █████╗ ", "██╔══██╗", "╚█████╔╝", "██╔══██╗", "╚█████╔╝", " ╚════╝ " },
    ["9"] = { " █████╗ ", "██╔══██╗", "╚██████║", " ╚═══██║", " █████╔╝", " ╚════╝ " },
    ["-"] = { "      ", "      ", "█████╗", "╚════╝", "      ", "      " },
    ["_"] = { "        ", "        ", "        ", "        ", "███████╗", "╚══════╝" },
    ["."] = { "   ", "   ", "   ", "   ", "██╗", "╚═╝" },
}

-- 3x5 bitmaps, one string per row, "#" = on. Rendered two rows per line with
-- ▀ ▄ █, so a letter is 3 lines tall.
-- stylua: ignore
local mini = {
  [" "] = { "...", "...", "...", "...", "..." },
  A = { ".#.", "#.#", "###", "#.#", "#.#" },
  B = { "##.", "#.#", "##.", "#.#", "##." },
  C = { ".##", "#..", "#..", "#..", ".##" },
  D = { "##.", "#.#", "#.#", "#.#", "##." },
  E = { "###", "#..", "##.", "#..", "###" },
  F = { "###", "#..", "##.", "#..", "#.." },
  G = { ".##", "#..", "#.#", "#.#", ".##" },
  H = { "#.#", "#.#", "###", "#.#", "#.#" },
  I = { "###", ".#.", ".#.", ".#.", "###" },
  J = { "..#", "..#", "..#", "#.#", ".#." },
  K = { "#.#", "#.#", "##.", "#.#", "#.#" },
  L = { "#..", "#..", "#..", "#..", "###" },
  M = { "#.#", "###", "###", "#.#", "#.#" },
  N = { "##.", "#.#", "#.#", "#.#", "#.#" },
  O = { ".#.", "#.#", "#.#", "#.#", ".#." },
  P = { "##.", "#.#", "##.", "#..", "#.." },
  Q = { ".#.", "#.#", "#.#", "##.", ".##" },
  R = { "##.", "#.#", "##.", "#.#", "#.#" },
  S = { ".##", "#..", ".#.", "..#", "##." },
  T = { "###", ".#.", ".#.", ".#.", ".#." },
  U = { "#.#", "#.#", "#.#", "#.#", "###" },
  V = { "#.#", "#.#", "#.#", "#.#", ".#." },
  W = { "#.#", "#.#", "###", "###", "#.#" },
  X = { "#.#", "#.#", ".#.", "#.#", "#.#" },
  Y = { "#.#", "#.#", ".#.", ".#.", ".#." },
  Z = { "###", "..#", ".#.", "#..", "###" },
  ["0"] = { "###", "#.#", "#.#", "#.#", "###" },
  ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
  ["2"] = { "##.", "..#", ".#.", "#..", "###" },
  ["3"] = { "##.", "..#", ".#.", "..#", "##." },
  ["4"] = { "#.#", "#.#", "###", "..#", "..#" },
  ["5"] = { "###", "#..", "##.", "..#", "##." },
  ["6"] = { ".##", "#..", "###", "#.#", "###" },
  ["7"] = { "###", "..#", ".#.", ".#.", ".#." },
  ["8"] = { "###", "#.#", "###", "#.#", "###" },
  ["9"] = { "###", "#.#", "###", "..#", "##." },
  ["-"] = { "...", "...", "###", "...", "..." },
  ["_"] = { "...", "...", "...", "...", "###" },
  ["."] = { "...", "...", "...", "...", ".#." },
}

local half = { ["##"] = "█", ["#."] = "▀", [".#"] = "▄", [".."] = " " }

--- Turn a mini bitmap into 3 lines of half blocks.
---@param rows string[]
---@return string[]
local function halve(rows)
  local out = {}
  for r = 1, 5, 2 do
    local top, bottom = rows[r], rows[r + 1] or "..."
    local line = {}
    for c = 1, 3 do
      line[c] = half[top:sub(c, c) .. bottom:sub(c, c)]
    end
    out[#out + 1] = table.concat(line)
  end
  return out
end

--- Join glyphs side by side. Returns nil if a character is missing.
---@param text string
---@param font table<string, string[]>
---@param gap string
---@return string[]?
local function draw(text, font, gap)
  local lines = {}
  for i = 1, #text do
    local glyph = font[text:sub(i, i)]
    if not glyph then
      return nil
    end
    for l, part in ipairs(glyph) do
      lines[l] = (lines[l] and lines[l] .. gap or "") .. part
    end
  end
  return lines
end

local mini_halved = {}
for ch, rows in pairs(mini) do
  mini_halved[ch] = halve(rows)
end

--- The biggest rendering of `text` that fits in `width` cells.
---@param text string
---@param width number
---@return string
function M.render(text, width)
  text = text:upper()
  for _, font in ipairs({ { shadow, "" }, { mini_halved, " " } }) do
    local lines = draw(text, font[1], font[2])
    if lines and vim.api.nvim_strwidth(lines[1]) <= width then
      return table.concat(lines, "\n")
    end
  end
  local spaced = vim.fn.join(vim.split(text, ""), " ")
  return vim.api.nvim_strwidth(spaced) <= width and spaced or text
end

--- Dashboard section: the cwd's folder name, sized to the dashboard window.
--- Also redraws the dashboard when the cwd changes (Open Project/Folder).
function M.section()
  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("dashboard_title", { clear = true }),
    callback = function()
      Snacks.dashboard.update()
    end,
  })
  return function(self)
    local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    if name == "" then
      name = "neovim"
    end
    -- a little margin so the letters never touch the window edge
    local width = (self._size and self._size.width or vim.o.columns) - 4
    return { header = M.render(name, width), padding = 1 }
  end
end

return M
