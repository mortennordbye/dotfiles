-- Generate a git commit message from the staged diff.
--
-- Typical flow: stage your changes, run `git commit` (which opens Neovim as
-- $EDITOR), press <leader>gm, review, tweak, then :wq. Outside a commit buffer
-- the message goes to the clipboard instead. In the Source Control panel's
-- commit box the same thing is <C-g>.
--
-- History: this used to call CopilotChat's `chat.ask`, then `claude -p` once
-- the copilot-chat extra was removed, because plain `copilot -p` took 42s and
-- printed a stats footer. With the flags in lua/config/commit_msg.lua it takes
-- ~10s with clean output, so it is back on Copilot.

local function generate()
  local target_buf = vim.api.nvim_get_current_buf()
  local in_commit_buf = vim.bo[target_buf].filetype == "gitcommit"

  local diff = vim.system({ "git", "diff", "--staged" }, { text = true }):wait()
  if diff.code ~= 0 then
    vim.notify("git diff --staged failed:\n" .. (diff.stderr or ""), vim.log.levels.ERROR, { title = "Commit message" })
    return
  end
  if vim.trim(diff.stdout or "") == "" then
    vim.notify("Nothing staged", vim.log.levels.WARN, { title = "Commit message" })
    return
  end

  require("config.commit_msg").generate(diff.stdout, function(text)
    if in_commit_buf and vim.api.nvim_buf_is_valid(target_buf) then
      -- Insert above line 1, the blank line git leaves for the message.
      vim.api.nvim_buf_set_lines(target_buf, 0, 0, false, vim.split(text, "\n"))
    else
      vim.fn.setreg("+", text)
      vim.notify("Commit message copied to clipboard", vim.log.levels.INFO, { title = "Commit message" })
    end
  end)
end

return {
  "folke/snacks.nvim", -- host spec; the keymap itself has no plugin dependency
  keys = {
    { "<leader>gm", generate, mode = "n", desc = "Generate commit message (Copilot)" },
  },
}
