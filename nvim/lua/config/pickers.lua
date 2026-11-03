-- Shared project/folder pickers.
--
-- Lives here rather than inside a plugin spec because two different places
-- need the same functions: the keymaps in lua/plugins/projects.lua and the
-- start screen in lua/plugins/ui.lua.

local M = {}

-- Where repositories actually live on this machine. snacks ships
-- { "~/dev", "~/projects" } as its default, neither of which exists here.
M.dev_roots = {
  "~/Documents/github",
  "~/Documents/gitlab",
  "~/Documents/local-git",
}

-- Root for the plain folder picker, and how deep to descend.
M.folder_roots = { "~/Documents" }
M.folder_depth = 2

local skip = { node_modules = true, [".git"] = true, target = true, dist = true }

--- Every git repository directly under `dev_roots`, most recently modified first.
---
--- The dashboard's built-in "projects" section does NOT use the picker's `dev`
--- setting -- it walks recent files and resolves each to its git root, so it
--- only ever lists repos you happened to open a file in. Passing this function
--- as that section's `dirs` makes it show real repositories instead.
---@return string[]
function M.repos()
  local found = {}
  for _, root in ipairs(M.dev_roots) do
    local base = vim.fn.expand(root)
    if vim.fn.isdirectory(base) == 1 then
      for name, type in vim.fs.dir(base) do
        local path = base .. "/" .. name
        if type == "directory" and vim.fn.isdirectory(path .. "/.git") == 1 then
          local stat = vim.uv.fs_stat(path)
          found[#found + 1] = { path = path, mtime = stat and stat.mtime.sec or 0 }
        end
      end
    end
  end
  table.sort(found, function(a, b)
    return a.mtime > b.mtime
  end)
  return vim.tbl_map(function(r)
    return r.path
  end, found)
end

--- Directories under `folder_roots`, up to `folder_depth` levels deep.
--- Unlike M.repos this does not require a git repo, so it also finds the
--- Obsidian/latex/Scripts style folders.
---@return snacks.picker.finder.Item[]
function M.find_folders()
  local items = {}
  for _, root in ipairs(M.folder_roots) do
    local base = vim.fn.expand(root)
    if vim.fn.isdirectory(base) == 1 then
      items[#items + 1] = { text = base, file = base, dir = true }
      for name, type in vim.fs.dir(base, { depth = M.folder_depth }) do
        local head = name:match("^[^/]+")
        local tail = vim.fs.basename(name)
        if type == "directory" and not tail:match("^%.") and not skip[tail] and not skip[head] then
          local path = base .. "/" .. name
          items[#items + 1] = { text = path, file = path, dir = true }
        end
      end
    end
  end
  return items
end

--- Pick a folder, make it the tab's cwd, and open the explorer there.
--- tcd rather than cd so other tabs keep their own project.
function M.folders()
  Snacks.picker.pick({
    source = "folders",
    title = "Folders",
    finder = M.find_folders,
    format = "file",
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.cmd.tcd(vim.fn.fnameescape(item.file))
        Snacks.picker.explorer({ cwd = item.file })
      end
    end,
  })
end

--- Pick a git repository and start there (loads its session if one exists).
function M.projects()
  Snacks.picker.projects()
end

return M
