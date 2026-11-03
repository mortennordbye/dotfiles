-- "Changes" sidebar: the explorer, but only files git reports as changed.
--
-- Roughly VSCode's Source Control list. It sits where the explorer sits (same
-- sidebar layout, `C` swaps between the two), keeps the folder tree so you can
-- see where a change lives, and previews in the main window: moving the cursor
-- over a file shows its diff there, <CR> opens the file itself.
--
-- Like the explorer patch in lua/config/explorer_git.lua it copes with a cwd
-- that is a folder of repositories rather than a repository.

local M = {}

local Git = require("snacks.picker.source.git")

---@param repo string
---@return {status: string, file: string, dir: boolean}[]
local function parse(repo, stdout)
  local ret, entries = {}, vim.split(stdout or "", "\0")
  local i = 1
  while i <= #entries do
    local status, file = entries[i]:match("^(..) (.+)$")
    if status then
      local dir = file:sub(-1) == "/"
      ret[#ret + 1] = { status = status, file = repo .. "/" .. (dir and file:sub(1, -2) or file), dir = dir }
      -- renames and copies carry the old path as the next entry
      if status:find("[RC]") then
        i = i + 1
      end
    end
    i = i + 1
  end
  return ret
end

---@type snacks.picker.finder
function M.finder(_, ctx)
  local cwd = svim.fs.normalize(ctx.filter.cwd)
  local root = Snacks.git.get_root(cwd)
  local top = root or cwd
  local repos = root and { root } or require("config.explorer_git").nested_repos(cwd)

  local jobs = {}
  for _, repo in ipairs(repos) do
    jobs[repo] = vim.system(
      { "git", "--no-pager", "--no-optional-locks", "status", "--porcelain=v1", "-z", "-unormal" },
      { cwd = repo }
    )
  end

  local rootItem = { file = top, dir = true, open = true, text = top, sort = "" }
  local items, dirs = { rootItem }, { [top] = rootItem }

  ---@param path string
  ---@param repo string
  local function dir_item(path, repo)
    if not dirs[path] then
      local parent = dir_item(vim.fs.dirname(path), repo)
      local inside = path == repo or path:find(repo .. "/", 1, true) == 1
      dirs[path] = {
        file = path,
        dir = true,
        open = true,
        text = path,
        parent = parent,
        cwd = inside and repo or nil,
        sort = parent.sort .. "!" .. vim.fs.basename(path) .. " ",
      }
      items[#items + 1] = dirs[path]
    end
    return dirs[path]
  end

  for repo, job in pairs(jobs) do
    for _, s in ipairs(parse(repo, job:wait().stdout)) do
      local parent = dir_item(vim.fs.dirname(s.file), repo)
      items[#items + 1] = {
        file = s.file,
        dir = s.dir,
        text = s.file,
        status = s.status,
        parent = parent,
        cwd = repo,
        sort = parent.sort .. (s.dir and "!" or "#") .. vim.fs.basename(s.file) .. " ",
      }
      -- folders show the strongest status of anything below them
      local p = parent
      while p and p ~= rootItem do
        p.status = p.status and Git.merge_status(p.status, s.status) or s.status
        p = p.parent
      end
    end
  end

  if #items == 1 then
    rootItem.comment = "  no changes"
  end

  -- tree guides need to know which child is drawn last under each parent
  table.sort(items, function(a, b)
    return a.sort < b.sort
  end)
  local last = {}
  for _, item in ipairs(items) do
    if item.parent then
      if last[item.parent] then
        last[item.parent].last = false
      end
      item.last = true
      last[item.parent] = item
    end
  end
  return items
end

---@param ctx snacks.picker.preview.ctx
function M.preview(ctx)
  if ctx.item.status and ctx.item.cwd then
    return Snacks.picker.preview.git_status(ctx)
  end
  ctx.preview:reset()
end

---@param cwd? string
function M.open(cwd)
  return Snacks.picker({
    title = "Changes",
    cwd = cwd,
    finder = M.finder,
    format = "file",
    formatters = { file = { filename_only = true } },
    preview = M.preview,
    sort = { fields = { "sort" } },
    matcher = { sort_empty = true },
    tree = true,
    focus = "list",
    auto_close = false,
    jump = { close = false },
    layout = { preset = "sidebar", preview = "main", layout = { width = 36, min_width = 36 } },
    confirm = function(picker, item)
      if item and not item.dir then
        picker:action("jump")
      end
    end,
    win = {
      list = {
        keys = {
          ["l"] = "confirm",
          ["u"] = {
            function(picker)
              picker:find()
            end,
            desc = "Refresh",
          },
          ["C"] = {
            function(picker)
              local dir = picker:cwd()
              picker:close()
              Snacks.picker.explorer({ cwd = dir })
            end,
            desc = "Back to explorer",
          },
        },
        wo = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
          statuscolumn = "",
          cursorline = true,
          winbar = "",
        },
      },
    },
  })
end

return M
