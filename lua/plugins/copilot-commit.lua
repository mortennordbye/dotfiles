-- Generate a git commit message from the staged diff.
--
-- Typical flow: stage your changes, run `git commit` (which opens Neovim as
-- $EDITOR), press <leader>gm, review, tweak, then :wq. Outside a commit buffer
-- the message goes to the clipboard instead.
--
-- History: this used to call CopilotChat's `chat.ask`. When the copilot-chat
-- extra was removed in favour of the Copilot CLI, the spec was `optional = true`
-- against CopilotChat.nvim, so the whole thing was skipped and <leader>gm
-- silently disappeared -- no error, just a missing key.
--
-- Rebuilt on a CLI one-shot instead, so it no longer depends on any chat plugin.
-- `claude -p` rather than `copilot -p`: measured on this machine, claude
-- answered a trivial prompt in 5.6s with clean output, while copilot took 42s,
-- burned 23.8 AI credits, and appended a stats footer that would need stripping.
-- To switch back, change CMD below to "copilot" and strip the trailing
-- "Changes / AI Credits / Tokens / Resume" block from the response.

local CMD = "claude"

local PROMPT = table.concat({
  "Write a git commit message for the staged changes in the diff on stdin,",
  "following the Conventional Commits / commitizen convention.",
  "Subject line in imperative mood, under 50 characters.",
  "Wrap the body at 72 characters and explain the *why*, not just the *what*.",
  "Return ONLY the raw commit message text:",
  "no code fences, no backticks, no surrounding explanation.",
}, " ")

local function generate()
  if vim.fn.executable(CMD) ~= 1 then
    vim.notify("`" .. CMD .. "` not found on PATH", vim.log.levels.WARN, { title = "Commit message" })
    return
  end

  local target_buf = vim.api.nvim_get_current_buf()
  local in_commit_buf = vim.bo[target_buf].filetype == "gitcommit"

  -- Read the staged diff ourselves rather than letting the agent run git: it
  -- needs no tool permissions that way, and the request stays a single turn.
  local diff = vim.system({ "git", "diff", "--staged" }, { text = true }):wait()
  if diff.code ~= 0 then
    vim.notify("git diff --staged failed:\n" .. (diff.stderr or ""), vim.log.levels.ERROR, { title = "Commit message" })
    return
  end
  if vim.trim(diff.stdout or "") == "" then
    vim.notify("Nothing staged", vim.log.levels.WARN, { title = "Commit message" })
    return
  end

  vim.notify("Generating commit message...", vim.log.levels.INFO, { title = "Commit message" })

  vim.system({ CMD, "-p", PROMPT }, { stdin = diff.stdout, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(
          "Generation failed (exit " .. res.code .. "):\n" .. (res.stderr or ""),
          vim.log.levels.ERROR,
          { title = "Commit message" }
        )
        return
      end

      -- Strip code fences the model may add despite the instruction.
      local text = vim.trim(res.stdout or "")
      text = text:gsub("^```%w*\n", ""):gsub("\n```$", "")
      if text == "" then
        vim.notify("Empty response", vim.log.levels.WARN, { title = "Commit message" })
        return
      end

      if in_commit_buf and vim.api.nvim_buf_is_valid(target_buf) then
        -- Insert above line 1, the blank line git leaves for the message.
        vim.api.nvim_buf_set_lines(target_buf, 0, 0, false, vim.split(text, "\n"))
      else
        vim.fn.setreg("+", text)
        vim.notify("Commit message copied to clipboard", vim.log.levels.INFO, { title = "Commit message" })
      end
    end)
  end)
end

return {
  "folke/snacks.nvim", -- host spec; the keymap itself has no plugin dependency
  keys = {
    { "<leader>gm", generate, mode = "n", desc = "Generate commit message (AI)" },
  },
}
