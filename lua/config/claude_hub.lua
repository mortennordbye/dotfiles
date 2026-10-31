-- Claude hub: every running Claude session on this machine in one view.
--
-- Each project runs in its own nvim with its own claudecode.nvim panel (the
-- "spokes"). This is the hub: a floating overlay, opened from any of them,
-- that lists every session with what it is doing, shows the selected one's
-- chat live, and can type into it, even when it lives in another nvim.
--
-- Where the data comes from, all plain files, nothing is polled over the
-- network or by spawning `claude`:
--   ~/.claude/sessions/<pid>.json      Claude's own registry of live sessions:
--                                      cwd, name, sessionId, status busy/idle.
--   ~/.claude/projects/<cwd>/<id>.jsonl  the session transcript.
--   ~/.claude/attention/<sessionId>    written by ~/.claude/hooks/claude-attention.sh:
--                                      "input <msg>" while Claude is blocked on
--                                      you, "done" when its turn has ended.
--
-- Talking to a session in another nvim: claudecode starts `claude` as a direct
-- child of nvim, so the session pid's parent is the owning nvim, and that nvim
-- listens on <stdpath("run") parent>/*/nvim.<ppid>.0. The hub connects over
-- RPC and has it write into the terminal whose job pid is the session.
--
-- The statusline component (wired in lua/plugins/lualine.lua) shows how many
-- sessions are waiting on you, and opens the hub when clicked.
local M = {}

local uv = vim.uv
local HOME = vim.env.HOME
local SESSIONS = HOME .. "/.claude/sessions"
local PROJECTS = HOME .. "/.claude/projects"
local ATTN = HOME .. "/.claude/attention"

-- Largest transcript tail read per render. A long session's jsonl runs to tens
-- of megabytes; the last few hundred KB cover far more chat than fits on screen.
local TAIL_BYTES = 512 * 1024

local ns = vim.api.nvim_create_namespace("claude_hub")

M.waiting = 0 -- sessions blocked on you, for the statusline and activity bar badge

-- Redraw the activity bar (lua/config/activitybar.lua) so its Claude Hub icon
-- shows the current badge and whether the hub is open.
local function bar_refresh()
  local bar = package.loaded["config.activitybar"]
  if bar and bar.refresh then
    pcall(bar.refresh)
  end
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

local function alive(pid)
  return pid and vim.api.nvim_get_proc(pid) ~= nil
end

--- Live sessions, each with its attention state folded in, sorted so the ones
--- that want you come first.
function M.sessions()
  local list = {}
  for _, path in ipairs(vim.fn.glob(SESSIONS .. "/*.json", false, true)) do
    local ok, s = pcall(vim.json.decode, read_file(path) or "")
    if ok and type(s) == "table" and s.sessionId and alive(s.pid) then
      s.project = s.cwd == HOME and "~" or vim.fs.basename(s.cwd or "?")
      local attn = read_file(ATTN .. "/" .. s.sessionId)
      if attn then
        local kind, msg = attn:match("^(%S+)%s*(.-)%s*$")
        s.attn, s.attn_msg = kind, msg
      end
      -- busy beats a stale "done": the marker is only cleared by the next prompt
      if s.attn == "input" then
        s.state = "input"
      elseif s.status == "busy" then
        s.state = "busy"
      else
        s.state = "idle"
      end
      table.insert(list, s)
    end
  end
  local rank = { input = 1, idle = 2, busy = 3 }
  table.sort(list, function(a, b)
    if rank[a.state] ~= rank[b.state] then
      return rank[a.state] < rank[b.state]
    end
    return a.project:lower() < b.project:lower()
  end)
  return list
end

local function transcript_path(s)
  local p = PROJECTS .. "/" .. s.cwd:gsub("[^%w%-]", "-") .. "/" .. s.sessionId .. ".jsonl"
  if uv.fs_stat(p) then
    return p
  end
  return vim.fn.glob(PROJECTS .. "/*/" .. s.sessionId .. ".jsonl", false, true)[1]
end

local function tail(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local size = uv.fs_fstat(fd).size
  local start = math.max(0, size - TAIL_BYTES)
  local data = uv.fs_read(fd, size - start, start) or ""
  uv.fs_close(fd)
  if start > 0 then
    data = data:gsub("^[^\n]*\n", "", 1) -- first line is cut mid-record
  end
  return data
end

local utc_offset = os.time() - os.time(os.date("!*t"))
local function clock(ts)
  local y, mo, d, h, mi, sec = (ts or ""):match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return ""
  end
  local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = sec }) + utc_offset
  return os.date("%H:%M", t)
end

local function tool_summary(item)
  local i = item.input or {}
  local what = i.description or i.command or i.file_path or i.pattern or i.url or i.prompt or ""
  what = tostring(what):gsub("\n.*", "")
  if #what > 90 then
    what = what:sub(1, 87) .. "..."
  end
  return ("> ⚙ **%s** %s"):format(item.name or "tool", what)
end

local function user_text(content)
  local text
  if type(content) == "string" then
    text = content
  elseif type(content) == "table" then
    local parts = {}
    for _, c in ipairs(content) do
      if c.type == "text" then
        table.insert(parts, c.text)
      end
    end
    text = table.concat(parts, "\n")
  end
  if not text or text == "" then
    return nil
  end
  local cmd = text:match("<command%-name>(.-)</command%-name>")
  if cmd then
    return "`" .. cmd .. "`"
  end
  if text:match("^%s*<") then
    return nil -- hook output, local command stdout, system reminders
  end
  return text
end

--- The chat as markdown lines: your prompts, Claude's replies, one line per tool.
local function render_transcript(path)
  local data = path and tail(path)
  if not data then
    return { "_No transcript yet._" }
  end
  local out = {}
  local last_role
  local function head(role, ts)
    if last_role ~= role then
      if #out > 0 then
        table.insert(out, "")
      end
      table.insert(out, ("## %s  %s"):format(role == "user" and "You" or "Claude", clock(ts)))
      table.insert(out, "")
      last_role = role
    end
  end
  for line in data:gmatch("[^\n]+") do
    local ok, e = pcall(vim.json.decode, line)
    if ok and type(e) == "table" and not e.isSidechain and not e.isMeta and e.message then
      if e.type == "user" then
        local t = user_text(e.message.content)
        if t then
          head("user", e.timestamp)
          vim.list_extend(out, vim.split(t, "\n"))
        end
      elseif e.type == "assistant" and type(e.message.content) == "table" then
        for _, c in ipairs(e.message.content) do
          if c.type == "text" and c.text ~= "" then
            head("assistant", e.timestamp)
            -- markdown would fold text straight after a "> tool" line into the quote
            if (out[#out] or ""):match("^>") then
              table.insert(out, "")
            end
            vim.list_extend(out, vim.split(c.text, "\n"))
            table.insert(out, "")
          elseif c.type == "tool_use" then
            head("assistant", e.timestamp)
            table.insert(out, tool_summary(c))
          end
        end
      end
    end
  end
  if #out == 0 then
    return { "_No messages yet._" }
  end
  return out
end

-- Sending keys into a session ------------------------------------------------

-- Runs inside the nvim that owns the session (locally, or over RPC). Finds the
-- terminal whose job is the claude process and writes to it. Text goes in as a
-- bracketed paste so newlines stay in the prompt; Enter follows separately, the
-- way a real keypress would, after Claude has taken the paste.
local SEND = [[
local pid, text, enter = ...
for _, c in ipairs(vim.api.nvim_list_chans()) do
  if c.mode == "terminal" then
    local ok, jp = pcall(vim.fn.jobpid, c.id)
    if ok and jp == pid then
      if text ~= "" then
        vim.fn.chansend(c.id, "\27[200~" .. text .. "\27[201~")
      end
      if enter then
        vim.defer_fn(function() vim.fn.chansend(c.id, "\r") end, text ~= "" and 120 or 0)
      end
      return true
    end
  end
end
return false
]]

local function owner_socket(ppid)
  local base = vim.fs.dirname(vim.fn.stdpath("run"))
  return vim.fn.glob(base .. "/*/nvim." .. ppid .. ".0", false, true)[1]
end

--- Type into a session, wherever it runs. `enter` presses Enter afterwards.
local function send(s, text, enter)
  local proc = vim.api.nvim_get_proc(s.pid)
  local ppid = proc and proc.ppid
  if not ppid then
    return vim.notify("Claude hub: session has exited", vim.log.levels.WARN)
  end
  local ok, res
  if ppid == vim.fn.getpid() then
    ok, res = pcall(assert(loadstring(SEND)), s.pid, text, enter)
  else
    local sock = owner_socket(ppid)
    if not sock then
      return vim.notify(
        ("Claude hub: %s is not running inside an nvim, reply in its own terminal"):format(s.project),
        vim.log.levels.WARN
      )
    end
    ok, res = pcall(function()
      local ch = vim.fn.sockconnect("pipe", sock, { rpc = true })
      local r = vim.rpcrequest(ch, "nvim_exec_lua", SEND, { s.pid, text, enter })
      vim.fn.chanclose(ch)
      return r
    end)
  end
  if not ok or not res then
    vim.notify("Claude hub: could not reach the Claude terminal in " .. s.project, vim.log.levels.WARN)
  end
end

-- The overlay ------------------------------------------------------------------

local H -- open hub: { list_buf, chat_buf, list_win, chat_win, items, timer, shown }

local ICON = {
  input = { "●", "DiagnosticError", "needs you" },
  idle = { "○", "DiagnosticWarn", "your turn" },
  busy = { "◐", "DiagnosticOk", "working" },
}

local HELP = {
  "",
  " ⏎  open in its nvim",
  " r  reply",
  " y  press Enter (accept)",
  " 1-3  pick option",
  " q  close",
}

local function selected()
  if not (H and vim.api.nvim_win_is_valid(H.list_win)) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(H.list_win)[1]
  return H.items[row]
end

local function show_chat(force)
  local s = selected()
  if not s then
    return
  end
  local path = transcript_path(s)
  local st = path and uv.fs_stat(path)
  local key = s.sessionId .. ":" .. (st and st.size or 0)
  if not force and H.shown == key then
    return
  end
  local win = H.chat_win
  local at_end = H.shown == nil
    or H.shown:match("^[^:]+") ~= s.sessionId
    or vim.api.nvim_win_get_cursor(win)[1] >= vim.api.nvim_buf_line_count(H.chat_buf) - 1
  H.shown = key

  local lines = render_transcript(path)
  vim.bo[H.chat_buf].modifiable = true
  vim.api.nvim_buf_set_lines(H.chat_buf, 0, -1, false, lines)
  vim.bo[H.chat_buf].modifiable = false

  local where = s.cwd:gsub("^" .. vim.pesc(HOME), "~")
  vim.api.nvim_win_set_config(win, { title = (" %s · %s "):format(s.name or s.project, where), title_pos = "center" })
  if at_end then
    vim.api.nvim_win_set_cursor(win, { #lines, 0 })
  end
end

local function render_list()
  local items = M.sessions()
  local prev = selected()
  H.items = items
  local lines, marks = {}, {}
  for i, s in ipairs(items) do
    local icon = ICON[s.state]
    local label = s.state == "input" and s.attn_msg ~= "" and s.attn_msg or icon[3]
    lines[i] = (" %s %-14s %s"):format(icon[1], s.project:sub(1, 14), label)
    marks[i] = icon[2]
  end
  if #items == 0 then
    lines = { " No Claude sessions running" }
  end
  local first_help = #lines + 1
  vim.list_extend(lines, HELP)

  vim.bo[H.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(H.list_buf, 0, -1, false, lines)
  vim.bo[H.list_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(H.list_buf, ns, 0, -1)
  for i, hl in pairs(marks) do
    vim.api.nvim_buf_set_extmark(H.list_buf, ns, i - 1, 1, { end_col = 4, hl_group = hl })
    vim.api.nvim_buf_set_extmark(H.list_buf, ns, i - 1, 20, { end_row = i, end_col = 0, hl_group = hl, strict = false })
  end
  for l = first_help, #lines do
    vim.api.nvim_buf_set_extmark(H.list_buf, ns, l - 1, 0, { end_row = l, hl_group = "Comment", strict = false })
  end

  -- keep the cursor on the same session as rows reorder
  local row = 1
  for i, s in ipairs(items) do
    if prev and s.sessionId == prev.sessionId then
      row = i
    end
  end
  if #items > 0 then
    vim.api.nvim_win_set_cursor(H.list_win, { row, 0 })
  end
end

local function refresh()
  if not (H and vim.api.nvim_win_is_valid(H.list_win) and vim.api.nvim_win_is_valid(H.chat_win)) then
    return M.close()
  end
  render_list()
  show_chat(false)
end

function M.close()
  if not H then
    return
  end
  local h = H
  H = nil
  if h.timer then
    h.timer:stop()
    h.timer:close()
  end
  for _, w in ipairs({ h.list_win, h.chat_win }) do
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
  bar_refresh()
end

function M.is_open()
  return H ~= nil
end

--- Jump to the session's panel. In this nvim that is a window switch; another
--- nvim cannot be brought to the front from here, so say where it lives.
local function open_spoke(s)
  local proc = vim.api.nvim_get_proc(s.pid)
  if proc and proc.ppid == vim.fn.getpid() then
    M.close()
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local b = vim.api.nvim_win_get_buf(w)
        local job = vim.bo[b].buftype == "terminal" and vim.b[b].terminal_job_pid
        if job == s.pid then
          vim.api.nvim_set_current_tabpage(tab)
          vim.api.nvim_set_current_win(w)
          vim.cmd.startinsert()
          return
        end
      end
    end
    vim.cmd("ClaudeCodeFocus")
  else
    vim.notify(
      ("%s runs in another nvim (%s). Reply here with r, or switch to that window."):format(
        s.project,
        s.cwd:gsub("^" .. vim.pesc(HOME), "~")
      )
    )
  end
end

local function map(buf, lhs, fn)
  vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
end

local function scratch(ft)
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "wipe"
  vim.bo[b].filetype = ft
  vim.bo[b].modifiable = false
  return b
end

function M.open()
  if H then
    return vim.api.nvim_set_current_win(H.list_win)
  end
  local cols, rows = vim.o.columns, vim.o.lines
  local width = math.min(cols - 4, math.max(100, math.floor(cols * 0.9)))
  local height = math.max(12, math.floor(rows * 0.85))
  local top = math.floor((rows - height) / 2) - 1
  local left = math.floor((cols - width) / 2)
  local list_w = 42

  local list_buf, chat_buf = scratch("claude_hub"), scratch("markdown")
  local list_win = vim.api.nvim_open_win(list_buf, true, {
    relative = "editor",
    row = top,
    col = left,
    width = list_w,
    height = height,
    border = "rounded",
    title = " Claude hub ",
    title_pos = "center",
    style = "minimal",
  })
  local chat_win = vim.api.nvim_open_win(chat_buf, false, {
    relative = "editor",
    row = top,
    col = left + list_w + 2,
    width = width - list_w - 2,
    height = height,
    border = "rounded",
    style = "minimal",
  })
  vim.wo[list_win].cursorline = true
  vim.wo[chat_win].wrap = true
  vim.wo[chat_win].linebreak = true
  vim.wo[chat_win].conceallevel = 2

  H = { list_buf = list_buf, chat_buf = chat_buf, list_win = list_win, chat_win = chat_win, items = {} }

  for _, b in ipairs({ list_buf, chat_buf }) do
    map(b, "q", M.close)
    map(b, "<C-q>", M.close)
    map(b, "<Tab>", function()
      local other = vim.api.nvim_get_current_win() == H.list_win and H.chat_win or H.list_win
      vim.api.nvim_set_current_win(other)
    end)
    vim.api.nvim_create_autocmd("WinClosed", {
      buffer = b,
      once = true,
      callback = function()
        vim.schedule(M.close)
      end,
    })
  end

  local function with_selected(fn)
    return function()
      local s = selected()
      if s then
        fn(s)
      end
    end
  end
  map(list_buf, "<CR>", with_selected(open_spoke))
  map(list_buf, "o", with_selected(open_spoke))
  map(list_buf, "r", with_selected(function(s)
    vim.ui.input({ prompt = "Reply to " .. s.project .. ": " }, function(text)
      if text and text ~= "" then
        send(s, text, true)
      end
    end)
  end))
  map(list_buf, "y", with_selected(function(s)
    send(s, "", true)
  end))
  for _, d in ipairs({ "1", "2", "3" }) do
    map(list_buf, d, with_selected(function(s)
      send(s, d, false)
    end))
  end
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = list_buf,
    callback = function()
      if H and H.items[vim.api.nvim_win_get_cursor(H.list_win)[1]] then
        show_chat(true)
      end
    end,
  })

  refresh()
  show_chat(true)
  H.timer = uv.new_timer()
  H.timer:start(1500, 1500, vim.schedule_wrap(refresh))
  bar_refresh()
end

function M.toggle()
  if H then
    M.close()
  else
    M.open()
  end
end

-- Statusline ---------------------------------------------------------------------

local bg_timer
function M.setup()
  if bg_timer then
    return
  end
  local function count()
    local n = 0
    for _, s in ipairs(M.sessions()) do
      if s.state == "input" then
        n = n + 1
      end
    end
    if n ~= M.waiting then
      M.waiting = n
      bar_refresh()
    end
  end
  count()
  bg_timer = uv.new_timer()
  bg_timer:start(3000, 3000, vim.schedule_wrap(count))
  -- a live uv timer can hold up exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if bg_timer and not bg_timer:is_closing() then
        bg_timer:stop()
        bg_timer:close()
      end
    end,
  })
end

function M.component()
  return ("\u{f06a9} %d waiting"):format(M.waiting)
end

return M
