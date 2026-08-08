return {
  "greggh/claude-code.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("claude-code").setup({
      -- Custom configurations can go here
    })
  end,
  keys = {
    { "<leader>cc", "<cmd>ClaudeCode<CR>", desc = "Toggle Claude Code" },
  },
}
