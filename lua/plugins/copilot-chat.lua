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
