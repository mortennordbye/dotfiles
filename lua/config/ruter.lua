-- Next departure home, in the statusline.
--
-- Backed by the `ruter` CLI (Entur/Ruter departures from your GPS position).
--
-- The CLI takes roughly 0.7s: GPS fix plus a network round trip. The statusline
-- redraws on nearly every keystroke, so it is never called from the component.
-- A timer refreshes in the background and the component only reads a cached
-- string.
--
-- Configure the destination with either of:
--   * `ruter config add hjem "<address>"` plus `default_destination` in
--     ~/.config/ruter/config.toml -- then nothing is needed here, and
--   * `vim.g.ruter_destination = "hjem"` in lua/config/options.lua, which is
--     passed to the CLI as the destination argument and wins over the default.
-- Until one of those exists the CLI exits with "ingen destinasjon oppgitt",
-- and this module stays silent rather than showing an error in the statusline.

local M = {}

local REFRESH_MS = 60 * 1000 -- normal cadence
local BACKOFF_MS = 15 * 60 * 1000 -- after a failure (usually: not configured yet)

-- Nerd Font glyphs as escapes; literal ones get stripped on write.
local ICONS = {
  bus = "\u{f207}",
  tram = "\u{f239}",
  metro = "\u{f239}",
  rail = "\u{f238}",
  water = "\u{f21a}",
}

---@type { text: string, minutes: number? }
M.state = { text = "", minutes = nil }

local timer, running
-- Assume focused at startup: nvim gets no FocusGained for the window it opens in.
local focused = true

--- "2026-08-08T09:10:20+02:00" -> epoch seconds.
--- Parsed as local time. The CLI emits Oslo time and this runs on a machine in
--- that zone, so the offset and the local zone agree; no cross-zone maths.
---@param iso string
---@return number?
local function to_epoch(iso)
  local y, mo, d, h, mi, s = iso:match("^(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then
    return nil
  end
  return os.time({
    year = tonumber(y),
    month = tonumber(mo),
    day = tonumber(d),
    hour = tonumber(h),
    min = tonumber(mi),
    sec = tonumber(s),
    isdst = nil,
  })
end

--- Turn the CLI's JSON into a short display string.
--- Reports minutes until you must LEAVE (the journey start, which includes the
--- walk to the stop), not until the vehicle departs -- that is the number you
--- actually act on.
---@param stdout string
---@return string text, number? minutes
local function render(stdout)
  local ok, journeys = pcall(vim.json.decode, stdout)
  if not ok or type(journeys) ~= "table" then
    return "", nil
  end
  local now = os.time()
  for _, j in ipairs(journeys) do
    local start = j.expectedStartTime and to_epoch(j.expectedStartTime)
    if start then
      local minutes = math.floor(os.difftime(start, now) / 60)
      if minutes >= 0 then
        -- First leg that is not walking carries the line number.
        for _, leg in ipairs(j.legs or {}) do
          if leg.mode and leg.mode ~= "foot" then
            local icon = ICONS[leg.mode] or ICONS.bus
            local line = leg.line and leg.line.publicCode or "?"
            return ("%s %s %dm"):format(icon, line, minutes), minutes
          end
        end
      end
    end
  end
  return "", nil
end

local function schedule(ms)
  if timer then
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(M.refresh))
  end
end

function M.refresh()
  if running or vim.fn.executable("ruter") ~= 1 then
    return
  end
  -- Each refresh is a GPS fix plus a network request. Left unguarded that is
  -- ~1400 of them a day, most while the window sits in the background. Skip
  -- the work when unfocused, but keep the timer ticking so it resumes on its
  -- own; FocusGained also forces an immediate refresh so the number is never
  -- stale when you look at it.
  if not focused then
    schedule(REFRESH_MS)
    return
  end
  running = true

  local cmd = { "ruter", "--json", "-n", "5" }
  local dest = vim.g.ruter_destination
  if type(dest) == "string" and dest ~= "" then
    cmd[#cmd + 1] = dest
  end

  vim.system(cmd, { text = true }, function(res)
    running = false
    if res.code ~= 0 or not res.stdout or res.stdout == "" then
      -- Almost always "no destination configured". Back off hard so a
      -- misconfigured setup does not spawn a process every minute forever.
      vim.schedule(function()
        M.state = { text = "", minutes = nil }
        schedule(BACKOFF_MS)
      end)
      return
    end
    local text, minutes = render(res.stdout)
    vim.schedule(function()
      M.state = { text = text, minutes = minutes }
      schedule(REFRESH_MS)
      -- Only repaint when there is something to show; avoids a redraw storm.
      if text ~= "" then
        vim.cmd("redrawstatus")
      end
    end)
  end)
end

function M.setup()
  if vim.fn.executable("ruter") ~= 1 or timer then
    return
  end
  timer = vim.uv.new_timer()

  local group = vim.api.nvim_create_augroup("ruter_statusline", { clear = true })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      focused = true
      M.refresh()
    end,
  })
  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    callback = function()
      focused = false
    end,
  })
  -- Close the handle explicitly; a live uv timer can hold up exit.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if timer then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
        timer = nil
      end
    end,
  })

  -- Small delay so startup is not competing with a GPS fix.
  schedule(2000)
end

--- lualine component.
function M.component()
  return M.state.text
end

--- Colour by urgency: red when you should already be walking, orange when it
--- is close, otherwise the normal statusline foreground.
function M.color()
  local m = M.state.minutes
  if not m then
    return nil
  end
  if m <= 2 then
    return { fg = "#ff757f", gui = "bold" } -- tokyonight red
  elseif m <= 5 then
    return { fg = "#ff966c" } -- orange
  end
  return nil
end

return M
