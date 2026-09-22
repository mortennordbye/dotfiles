-- Git status in the explorer when its root is a folder OF repositories.
--
-- snacks only asks git for status from the repo that contains the explorer's
-- cwd. Open the explorer on something like ~/Documents/notes, which is not a
-- repo itself but holds several, and every file shows up without a git marker.
--
-- This wraps snacks.explorer.git: when the cwd has no git root, it finds repos
-- up to `depth` levels below it, runs `git status` in each, and hands the
-- combined result to snacks' own tree update. Markers then show on files and
-- bubble up to their parent folders exactly as they do inside a single repo.
--
-- Loaded through package.preload from lua/plugins/explorer.lua, so the patch
-- is in place before the explorer first requires the module.

local M = {}

local depth = 2
-- snacks caches status for 15 min and relies on watching <repo>/.git/index to
-- invalidate it. That watcher only covers the cwd's own repo, so keep the
-- cache short here instead: commits made in a terminal show up on the next
-- explorer refresh rather than a quarter of an hour later.
local ttl = 5

local skip = { node_modules = true, [".git"] = true }

---@param dir string
---@param level? integer
---@param out? string[]
---@return string[]
function M.nested_repos(dir, level, out)
  level, out = level or 1, out or {}
  for name, type in vim.fs.dir(dir) do
    if type == "directory" and not skip[name] then
      local path = dir .. "/" .. name
      if vim.uv.fs_stat(path .. "/.git") then
        out[#out + 1] = path
      elseif level < depth then
        M.nested_repos(path, level + 1, out)
      end
    end
  end
  return out
end

---@param Git table the snacks.explorer.git module
function M.patch(Git)
  local update, is_dirty = Git.update, Git.is_dirty

  Git.is_dirty = function(cwd)
    if Snacks.git.get_root(cwd) then
      return is_dirty(cwd)
    end
    return Git.state[cwd] ~= nil and Git.state[cwd].last == 0
  end

  Git.update = function(cwd, opts)
    if Snacks.git.get_root(cwd) then
      return update(cwd, opts)
    end
    opts = opts or {}

    -- Keyed on cwd rather than a repo root; Git.refresh(path) still resets it
    -- because every changed path lies under cwd.
    Git.state[cwd] = Git.state[cwd] or { tick = 0, last = 0 }
    local state = Git.state[cwd]
    local now = os.time()
    if not opts.force and now - state.last < ttl then
      return
    end
    state.last = now
    state.tick = state.tick + 1
    local tick = state.tick

    local repos = M.nested_repos(cwd)
    if #repos == 0 then
      return Git._update(cwd, {})
    end

    local results, pending = {}, #repos
    for _, repo in ipairs(repos) do
      vim.system({
        "git",
        "--no-pager",
        "--no-optional-locks",
        "status",
        "--porcelain=v1",
        "--ignored=matching",
        "-z",
        opts.untracked and "-unormal" or "-uno",
      }, { cwd = repo }, function(res)
        for _, line in ipairs(vim.split(res.stdout or "", "\0")) do
          local status, file = line:match("^(..) (.+)$")
          if status then
            results[#results + 1] = { status = status, file = repo .. "/" .. file }
          end
        end
        pending = pending - 1
        if pending == 0 then
          vim.schedule(function()
            if Git.state[cwd] ~= state or state.tick ~= tick then
              return
            end
            if Git._update(cwd, results) and opts.on_update then
              opts.on_update()
            end
          end)
        end
      end)
    end
  end
end

return M
