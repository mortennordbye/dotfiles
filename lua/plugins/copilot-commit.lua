-- Generate a git commit message from staged changes using GitHub Copilot.
--
-- Two ways to use it:
--   :CopilotChatCommit   -> built-in prompt, shows the message in the chat window
--   <leader>gm           -> generate + auto-insert into the current `git commit`
--                           buffer, or copy to clipboard if you're not in one.
--
-- Typical flow: stage your changes, run `git commit` (opens Neovim as $EDITOR),
-- press <leader>gm, review, tweak, then :wq.

return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    optional = true, -- only applies if the ai.copilot-chat extra is enabled
    keys = {
      {
        "<leader>gm",
        function()
          local chat = require("CopilotChat")
          local prompt = table.concat({
            "Write a git commit message for the staged changes,",
            "following the Conventional Commits / commitizen convention.",
            "Subject line in imperative mood, under 50 characters.",
            "Wrap the body at 72 characters and explain the *why*, not just the *what*.",
            "Return ONLY the raw commit message text:",
            "no code fences, no backticks, no surrounding explanation.",
            "#gitdiff:staged",
          }, " ")

          local target_buf = vim.api.nvim_get_current_buf()
          local in_commit_buf = vim.bo[target_buf].filetype == "gitcommit"

          chat.ask(prompt, {
            callback = function(response)
              -- response may be a table {content=...} or a plain string
              local text = type(response) == "table" and (response.content or "") or tostring(response)
              -- strip any code fences the model added despite instructions
              text = text:gsub("^%s*```%w*\n", ""):gsub("\n```%s*$", ""):gsub("^%s+", "")

              vim.schedule(function()
                if in_commit_buf and vim.api.nvim_buf_is_valid(target_buf) then
                  local lines = vim.split(text, "\n")
                  -- insert above line 1 (the blank line git leaves for the message)
                  vim.api.nvim_buf_set_lines(target_buf, 0, 0, false, lines)
                else
                  vim.fn.setreg("+", text)
                  vim.notify("Commit message copied to clipboard (register +)", vim.log.levels.INFO)
                end
              end)

              return response
            end,
          })
        end,
        mode = "n",
        desc = "Generate commit message (Copilot)",
      },
    },
  },
}
