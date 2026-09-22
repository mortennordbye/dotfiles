-- A "Source Control" section at the bottom of the explorer, under the tree.
--
-- Snacks can't stack two pickers in one sidebar, so instead of a second panel
-- this appends extra rows to the explorer's own list, laid out like VSCode's
-- Source Control view:
--
--   ─────────────────────────────
--   Source Control
--   + s stage  ⊸ gc commit  ↑ gp push     (key hints, with icons)
--   ─────────────────────────────
--   󰊢 repo   main ↑1 (3)
--     Staged (1)
--       file.lua  some/folder
--     Changes (2)
--       ...
--
-- One repo row per repository with changes, so a folder that holds several
-- repos (see lua/config/explorer_git.lua) gets one group each.
--
-- Keys on these rows (wired in lua/plugins/explorer.lua):
--   s   stage / unstage the file, or everything under a group or repo row
--   gc  commit the repo under the cursor (opens a message box)
--   gp  push it; the repo row shows ↑N while there are commits to push, and
--       "↑N publish" for a branch that has never been pushed
--
-- File status comes from the explorer, which already asks git and stores the
-- result on the tree nodes; this reads them back, and when git status
-- refreshes the explorer re-runs its finder and the section follows. The only
-- git call of its own is the ↑N count, run in the background (see ahead()).

local M = {}

---@param cwd string
---@return {path: string, status: string, dir: boolean}[]
local function changed(cwd)
  local Tree = require("snacks.explorer.tree")
  local ret = {}
  Tree:walk(Tree:find(cwd), function(node)
    local s = node.status
    -- dirs only when git reports the folder itself (a new, untracked folder);
    -- other folders just carry the status of what is inside them
    if s and not s:find("^!") and (not node.dir or node.dir_status) then
      ret[#ret + 1] = { path = node.path, status = s, dir = node.dir }
    end
  end, { all = true })
  table.sort(ret, function(a, b)
    return a.path < b.path
  end)
  return ret
end

--- Current branch of `repo`, or a short commit hash when HEAD is detached.
---@param repo string
---@return string?, boolean?
local function branch(repo)
  -- worktrees and submodules keep .git as a file; no branch shown for those
  local f = io.open(repo .. "/.git/" .. "HEAD")
  if not f then
    return
  end
  local head = f:read("*l") or ""
  f:close()
  local ref = head:match("^ref: refs/heads/(.+)$")
  if ref then
    return ref
  end
  return head:sub(1, 7), true
end

---@param cwd string
---@return string[]
local function repos(cwd)
  local root = Snacks.git.get_root(cwd)
  return root and { root } or require("config.explorer_git").nested_repos(cwd)
end

--- One half of a git status (XY): the staged side X or the working-tree side Y.
---@param entry {path: string, status: string, dir: boolean}
---@param repo string
---@param staged boolean
local function file_item(entry, repo, staged)
  local x, y = entry.status:sub(1, 1), entry.status:sub(2, 2)
  local status
  if entry.status == "??" then
    status = not staged and "??" or nil
  elseif staged then
    status = x ~= " " and (x .. " ") or nil
  else
    status = y ~= " " and (" " .. y) or nil
  end
  if not status then
    return
  end
  local dir = vim.fs.dirname(entry.path:sub(#repo + 2))
  return {
    file = entry.path,
    text = entry.path,
    dir = entry.dir,
    status = status,
    comment = dir ~= "." and dir or nil,
    scm = { repo = repo, staged = staged, path = entry.path },
    indent = "    ",
  }
end

--- Commits on HEAD that aren't pushed yet. For a branch with an upstream
--- that is `@{upstream}..HEAD`; for one without (never pushed) it is the
--- commits no remote has, flagged `publish` so the row can say so. Repos with
--- no remote at all report nothing: there is nowhere to push.
---
--- The finder runs inside snacks' coroutine, where waiting on a process hangs,
--- so this answers from a cache and refreshes it in the background (at most
--- every few seconds), re-running the list only when the answer changed.
local ahead_cache = {} ---@type table<string, {n?: integer, publish?: boolean, at: integer}>

---@param repo string
---@param cb fun(n?: integer, publish?: boolean)
local function count_ahead(repo, cb)
  local function run(args, on_exit)
    vim.system(vim.list_extend({ "git" }, args), { cwd = repo, text = true }, on_exit)
  end
  run({ "rev-list", "--count", "@{upstream}..HEAD" }, function(res)
    if res.code == 0 then
      return cb(tonumber(vim.trim(res.stdout)))
    end
    run({ "remote" }, function(remotes)
      if vim.trim(remotes.stdout or "") == "" then
        return cb()
      end
      run({ "rev-list", "--count", "HEAD", "--not", "--remotes" }, function(r)
        cb(r.code == 0 and tonumber(vim.trim(r.stdout)) or nil, true)
      end)
    end)
  end)
end

---@param repo string
---@param picker snacks.Picker
---@return {n?: integer, publish?: boolean}
local function ahead(repo, picker)
  local c = ahead_cache[repo]
  if c and os.time() - c.at < 5 then
    return c
  end
  local old = c or { at = 0 }
  ahead_cache[repo] = { n = old.n, publish = old.publish, at = os.time() }
  count_ahead(repo, function(n, publish)
    local entry = ahead_cache[repo]
    if not entry then
      return
    end
    entry.n, entry.publish = n, publish
    if n ~= old.n or publish ~= old.publish then
      vim.schedule(function()
        if not picker.closed then
          picker.list:set_target()
          picker:find()
        end
      end)
    end
  end)
  return old
end

---@type snacks.picker.finder
function M.finder(opts, ctx)
  local tree = require("snacks.picker.source.explorer").explorer(opts, ctx)
  -- while typing a search the explorer shows fd results instead of the tree
  if not ctx.filter:is_empty() then
    return tree
  end
  return function(cb)
    tree(cb)
    local cwd = ctx.filter.cwd
    local entries = changed(cwd)

    -- Build every repo's rows first: a repo is listed when it has changes or
    -- unpushed commits, and the header only appears when something is listed.
    local rows = {}
    for _, repo in ipairs(repos(cwd)) do
      local mine = vim.tbl_filter(function(e)
        return e.path:find(repo .. "/", 1, true) == 1
      end, entries)
      local up = ahead(repo, ctx.picker)
      if #mine > 0 or (up.n or 0) > 0 then
        local staged, unstaged = {}, {}
        for _, e in ipairs(mine) do
          staged[#staged + 1] = file_item(e, repo, true)
          unstaged[#unstaged + 1] = file_item(e, repo, false)
        end
        local name, detached = branch(repo)
        rows[#rows + 1] = {
          text = "",
          section = vim.fs.basename(repo),
          repo_row = true,
          branch = name,
          detached = detached,
          count = #mine,
          ahead = up.n,
          publish = up.publish,
          -- s on the repo row stages everything, or unstages once all is staged
          scm = { repo = repo, staged = #unstaged == 0 },
        }
        for _, group in ipairs({ { "Staged", staged, true }, { "Changes", unstaged, false } }) do
          local label, items, is_staged = group[1], group[2], group[3]
          if #items > 0 then
            rows[#rows + 1] = {
              text = "",
              section = label .. " (" .. #items .. ")",
              group = true,
              scm = { repo = repo, staged = is_staged },
            }
            vim.list_extend(rows, items)
          end
        end
      end
    end
    if #rows == 0 then
      return
    end
    cb({ text = "", section = "", rule = true })
    cb({ text = "", section = "Source Control" })
    cb({ text = "", section = "", keys_hint = true })
    cb({ text = "", section = "", rule = true })
    for _, row in ipairs(rows) do
      cb(row)
    end
  end
end

---@type snacks.picker.format
function M.format(item, picker)
  if item.rule then
    -- cut to the window's width by the list itself
    return { { string.rep("─", 200), "SnacksPickerTree" } }
  elseif item.repo_row then
    local ret = {
      { "\u{f02a2} ", "SnacksPickerDirectory" },
      { item.section, "SnacksPickerDirectory" },
    }
    if item.branch then
      ret[#ret + 1] = { "  \u{e725} " .. item.branch, item.detached and "SnacksPickerGitDetached" or "SnacksPickerGitBranch" }
    end
    if (item.ahead or 0) > 0 then
      ret[#ret + 1] = { " \u{2191}" .. item.ahead .. (item.publish and " publish" or ""), "SnacksPickerGitStatusAdded" }
    end
    ret[#ret + 1] = { " (" .. item.count .. ")", "SnacksPickerComment" }
    return ret
  elseif item.keys_hint then
    -- what the keys do, on their own line under the header
    local ret = {}
    for _, k in ipairs({
      { "\u{f0415}", "s", "stage" }, -- plus
      { "\u{f0718}", "gc", "commit" }, -- source-commit
      { "\u{f005d}", "gp", "push" }, -- arrow-up
    }) do
      ret[#ret + 1] = { (#ret == 0 and "" or "  ") .. k[1] .. " ", "SnacksPickerComment" }
      ret[#ret + 1] = { k[2], "SnacksPickerSpecial" }
      ret[#ret + 1] = { " " .. k[3], "SnacksPickerComment" }
    end
    return ret
  elseif item.group then
    return { { "  " }, { item.section, "SnacksPickerSpecial" } }
  elseif item.section then
    return { { item.section, "SnacksPickerTitle" } }
  end
  local ret = Snacks.picker.format.file(item, picker)
  if item.indent then
    table.insert(ret, 1, { item.indent })
  end
  if item.comment then
    -- file() already appends the folder as a comment. Pad it off the filename
    -- and fit it into what is left of the row: the git status marker is drawn
    -- right-aligned on top of the text, so an overlong path runs into it.
    -- Cut from the left, keeping the most specific folder.
    local idx, used = nil, 0
    for i, h in ipairs(ret) do
      if h[1] == item.comment then
        idx = i
      elseif type(h[1]) == "string" then
        used = used + vim.api.nvim_strwidth(h[1])
      end
    end
    if idx then
      local room = vim.api.nvim_win_get_width(picker.list.win.win) - used - 1 - 4 -- pad, marker + gap
      local text = item.comment
      if room < 6 then
        table.remove(ret, idx)
        -- no room for the folder; shorten the name itself if it still overflows
        local over = used + 4 - vim.api.nvim_win_get_width(picker.list.win.win)
        local name = vim.fs.basename(item.file)
        for i, h in ipairs(ret) do
          if over > 0 and h[1] == name then
            ret[i] = { vim.fn.strcharpart(name, 0, vim.fn.strchars(name) - over - 1) .. "…", h[2] }
          end
        end
      else
        if vim.api.nvim_strwidth(text) > room then
          text = "…" .. vim.fn.strcharpart(text, vim.fn.strchars(text) - (room - 1))
        end
        ret[idx] = { text, ret[idx][2] }
        table.insert(ret, idx, { " " })
      end
    end
  end
  return ret
end

--- Make the explorer's confirm ignore the divider and header rows, which have
--- no file to open. Patched into the actions module itself (see the preload in
--- lua/plugins/explorer.lua) because the explorer binds that function directly
--- for <CR>, l and double-click, so a key override alone misses some of them.
---@param Actions table the snacks.explorer.actions module
function M.patch_actions(Actions)
  local confirm = Actions.actions.confirm
  Actions.actions.confirm = function(picker, item, action)
    if item and item.section then
      return
    end
    return confirm(picker, item, action)
  end
end

---@param picker snacks.Picker
---@param repo string
local function refresh(picker, repo)
  ahead_cache[repo] = nil
  require("snacks.explorer.git").refresh(repo)
  require("snacks.explorer.actions").update(picker, { refresh = true })
end

---@param args string[]
---@param repo string
---@param on_done fun(res: vim.SystemCompleted)
---@param stdin? string
local function git(args, repo, on_done, stdin)
  vim.system(vim.list_extend({ "git" }, args), { cwd = repo, text = true, stdin = stdin }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(vim.trim(res.stderr or res.stdout or ""), vim.log.levels.ERROR, { title = "git " .. args[1] })
        return
      end
      on_done(res)
    end)
  end)
end

--- The repo that a row belongs to: its Source Control group, the repo holding
--- the file or folder under the cursor, or the only repo listed.
---@return string?
local function repo_for(picker, item)
  if item and item.scm then
    return item.scm.repo
  end
  local root = item and item.file and Snacks.git.get_root(item.file)
  if root then
    return root
  end
  local found = {}
  for _, it in ipairs(picker:items()) do
    if it.repo_row then
      found[#found + 1] = it.scm.repo
    end
  end
  return #found == 1 and found[1] or nil
end

--- `s`: stage what's under the cursor, or unstage it if it is already staged.
function M.toggle_stage(picker, item)
  local scm = item and item.scm
  if not scm then
    return
  end
  local args = scm.staged and { "reset", "-q", "--" } or { "add", "-A", "--" }
  args[#args + 1] = scm.path or "."
  git(args, scm.repo, function()
    refresh(picker, scm.repo)
  end)
end

--- Floating, multi-line message box like VSCode's. Starts in insert mode;
--- <C-s> (or <CR> in normal mode) commits, <Esc> in normal mode or q cancels.
---@param title string
---@param on_submit fun(msg: string)
local function message_box(title, on_submit)
  local function submit(win)
    local lines = vim.api.nvim_buf_get_lines(win.buf, 0, -1, false)
    local msg = vim.trim(table.concat(lines, "\n"))
    win:close()
    vim.cmd.stopinsert()
    if msg ~= "" then
      on_submit(msg)
    end
  end
  Snacks.win({
    position = "float",
    width = 64,
    height = 8,
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = " <C-s> commit   <Esc> then q cancel ",
    footer_pos = "center",
    bo = { filetype = "gitcommit" },
    enter = true,
    wo = { wrap = true, spell = true, number = false, relativenumber = false, signcolumn = "no" },
    keys = {
      submit_i = { "<C-s>", submit, mode = { "n", "i" }, desc = "Commit" },
      submit_n = { "<CR>", submit, mode = "n", desc = "Commit" },
      q = "close",
      ["<Esc>"] = "close",
    },
  })
  vim.cmd.startinsert()
end

--- `gc`: commit the repo under the cursor.
function M.commit(picker, item)
  local repo = repo_for(picker, item)
  if not repo then
    vim.notify("Put the cursor on a repo under Source Control first", vim.log.levels.WARN, { title = "git commit" })
    return
  end

  local name = vim.fs.basename(repo)
  git({ "diff", "--cached", "--name-only" }, repo, function(res)
    local staged = #vim.split(vim.trim(res.stdout or ""), "\n", { trimempty = true })
    -- Like VSCode's smart commit: nothing staged means commit every tracked
    -- change (`commit -a`). Untracked files are left alone; stage those with s.
    local all = staged == 0
    local title = all and ("Commit all tracked changes in " .. name)
      or ("Commit " .. staged .. " staged file" .. (staged == 1 and "" or "s") .. " in " .. name)
    message_box(title, function(msg)
      git(all and { "commit", "-a", "-F", "-" } or { "commit", "-F", "-" }, repo, function(done)
        vim.notify(
          vim.split(vim.trim(done.stdout or ""), "\n")[1] .. "\n\ngp to push",
          vim.log.levels.INFO,
          { title = "git commit" }
        )
        refresh(picker, repo)
      end, msg)
    end)
  end)
end

--- `gp`: push the repo under the cursor. A branch with no upstream yet is
--- pushed to origin and set to track it, like VSCode's "Publish Branch".
function M.push(picker, item)
  local repo = repo_for(picker, item)
  if not repo then
    vim.notify("Put the cursor on a repo first", vim.log.levels.WARN, { title = "git push" })
    return
  end
  local name = vim.fs.basename(repo)
  local has_upstream = vim.system({ "git", "rev-parse", "--abbrev-ref", "@{upstream}" }, { cwd = repo }):wait().code == 0
  local args = has_upstream and { "push" } or { "push", "-u", "origin", "HEAD" }
  vim.notify("Pushing " .. name .. "...", vim.log.levels.INFO, { title = "git push" })
  git(args, repo, function(res)
    -- git reports push progress and the result on stderr
    local out = vim.split(vim.trim(res.stderr ~= "" and res.stderr or res.stdout or ""), "\n")
    vim.notify(name .. ": " .. out[#out], vim.log.levels.INFO, { title = "git push" })
    refresh(picker, repo)
  end)
end

return M
