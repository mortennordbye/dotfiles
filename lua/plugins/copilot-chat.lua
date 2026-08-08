-- CopilotChat keymaps.
--
-- Two LazyVim extras both claim <leader>aa: copilot-chat maps it to Toggle, and
-- claudecode maps it to "Accept diff". copilot-chat won, which left Claude's
-- accept unreachable -- you could deny a diff with <leader>ad but only accept
-- one by running :ClaudeCodeDiffAccept by hand.
--
-- Claude is the primary workflow here, and accept/deny should be a pair, so
-- <leader>aa goes to Claude (see lua/plugins/claudecode.lua) and CopilotChat's
-- toggle moves to <leader>at.
return {
  "CopilotC-Nvim/CopilotChat.nvim",
  optional = true,

  -- Stop the chat header wrapping into an unreadable mess.
  --
  -- CopilotChat writes each section header into the buffer as
  --   #  <user>  (<36-char message uuid>) ───
  -- then hides it behind an `virt_text_pos = "overlay"` extmark that draws the
  -- pretty pill and rule. An overlay only paints the FIRST screen row, so as
  -- soon as that line is wider than the window it wraps and the raw text --
  -- the tail of the uuid -- shows through on the next row.
  --
  -- Measured at 140 editor columns: window 56 cells, header line 74. The uuid
  -- is fixed at 36 and not configurable, so the two levers are the username
  -- (LazyVim derives it from $USER, giving the 21-char "First.last")
  -- and the window width. Shortening the name to "Morten" and going 0.40 ->
  -- 0.45 takes the line to ~54 in a ~63-cell window.
  --
  -- Function form, not a table: the LazyVim extra's own `opts` is a function
  -- that returns a fresh table and ignores what it was passed, so a plain table
  -- here would be discarded if spec order ever changed.
  opts = function(_, opts)
    opts.headers = opts.headers or {}
    opts.headers.user = "\u{f007} Morten " -- nf-fa-user; escape, literal glyphs get stripped
    opts.window = opts.window or {}
    opts.window.width = 0.45
    return opts
  end,

  keys = {
    -- Unmap the stock binding so it stops shadowing Claude's accept.
    -- The mode list must match the extra's exactly ({ "n", "x" }, not
    -- { "n", "v" }): lazy.nvim matches a key override by lhs AND mode, so a
    -- mismatched list silently leaves the other mode's mapping in place.
    { "<leader>aa", false, mode = { "n", "x" } },
    {
      "<leader>at",
      function()
        return require("CopilotChat").toggle()
      end,
      desc = "Toggle (CopilotChat)",
      mode = { "n", "x" },
    },
  },
}
