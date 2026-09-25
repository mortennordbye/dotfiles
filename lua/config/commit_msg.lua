-- AI commit message from a diff, via the Copilot CLI. Shared by <leader>gm
-- (lua/plugins/copilot-commit.lua) and the Source Control message box's <C-g>
-- (lua/config/explorer_changes.lua), which is the ✨ button of VSCode.
--
-- The flags are what make `copilot -p` usable for this; measured on this
-- machine, a small diff takes ~10s:
--   -s                  output only the message, no stats footer
--   --model gpt-5-mini  fast, and a 0x model so it costs no premium requests
--   --available-tools view, and the diff in the prompt: piped on stdin it was
--                       ignored and the agent ran git itself instead (50s)
--
-- Like VSCode, the prompt also carries the repo's recent commit subjects so
-- the message matches the style already in use there.
--
-- Copilot still signs off with a `Co-authored-by: Copilot` trailer; that is
-- stripped, since commits here carry no agent trailers.

local M = {}

local CMD = "copilot"
local MODEL = "gpt-5-mini"
-- keeps the prompt well under the OS argument limit
local MAX_DIFF = 60000

local PROMPT = table.concat({
  "Write a git commit message for the diff below.",
  "Match the style of the repository's recent commits listed below",
  "(prefixes, scopes, casing); with none listed, use Conventional Commits.",
  "Subject line in imperative mood, under 50 characters.",
  "Wrap the body at 72 characters and explain the *why*, not just the *what*.",
  "Do not use any tools; everything you need is in the diff.",
  "Return ONLY the raw commit message text:",
  "no code fences, no backticks, no trailers, no surrounding explanation.",
}, " ")

---@param diff string
---@param on_done fun(msg: string) called on the main loop; not called on failure
---@param cwd? string the repo, for its recent commits; defaults to Neovim's cwd
function M.generate(diff, on_done, cwd)
  if vim.fn.executable(CMD) ~= 1 then
    vim.notify("`" .. CMD .. "` not found on PATH", vim.log.levels.WARN, { title = "Commit message" })
    return
  end
  if vim.trim(diff) == "" then
    vim.notify("Nothing to describe: no changes", vim.log.levels.WARN, { title = "Commit message" })
    return
  end
  if #diff > MAX_DIFF then
    diff = diff:sub(1, MAX_DIFF) .. "\n[diff truncated]"
  end

  -- empty in a repo with no commits yet, which is fine
  local log = vim.system({ "git", "log", "-n", "10", "--format=%s" }, { cwd = cwd, text = true }):wait()
  local recent = log.code == 0 and vim.trim(log.stdout or "") or ""
  local prompt = PROMPT
  if recent ~= "" then
    prompt = prompt .. "\n\nRecent commits:\n" .. recent
  end

  vim.notify("Generating commit message...", vim.log.levels.INFO, { title = "Commit message" })
  local args = {
    CMD, "-s", "--model", MODEL, "--reasoning-effort", "low",
    "--no-custom-instructions", "--available-tools", "view",
    "-p", prompt .. "\n\nDiff:\n" .. diff,
  }
  vim.system(args, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(
          "Generation failed (exit " .. res.code .. "):\n" .. (res.stderr or ""),
          vim.log.levels.ERROR,
          { title = "Commit message" }
        )
        return
      end

      local lines = {}
      for _, line in ipairs(vim.split(res.stdout or "", "\n")) do
        -- code fences the model may add despite the instruction, and trailers
        if not line:match("^```") and not line:match("^Co%-authored%-by:") then
          lines[#lines + 1] = line
        end
      end
      local text = vim.trim(table.concat(lines, "\n"))
      if text == "" then
        vim.notify("Empty response", vim.log.levels.WARN, { title = "Commit message" })
        return
      end
      on_done(text)
    end)
  end)
end

return M
