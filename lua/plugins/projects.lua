-- Project and folder navigation.
--
-- Two different needs, two pickers:
--   <leader>fp  Projects -- git repos only, resolved by root pattern (.git,
--               package.json, Makefile, ...). Also feeds the dashboard's
--               "Projects" section.
--   <leader>fD  Folders  -- any directory under ~/Documents, git or not, for
--               the Obsidian/latex/Scripts style folders that have no repo.

-- Where repositories actually live on this machine. snacks ships
-- { "~/dev", "~/projects" } as the default, neither of which exists here, so
-- the Projects list was falling back to whatever recent files happened to
-- imply -- which is why it only ever showed two entries.
local DEV_ROOTS = {
  "~/Documents/github",
  "~/Documents/gitlab",
  "~/Documents/local-git",
}

-- Root for the plain folder picker.
local FOLDER_ROOTS = { "~/Documents" }
local FOLDER_DEPTH = 2

--- Directories under `roots`, up to FOLDER_DEPTH levels deep.
--- Skips dotted and vendor directories so the list stays navigable.
local function find_folders()
  local skip = { node_modules = true, [".git"] = true, target = true, dist = true }
  local items = {}
  for _, root in ipairs(FOLDER_ROOTS) do
    local base = vim.fn.expand(root)
    if vim.fn.isdirectory(base) == 1 then
      items[#items + 1] = { text = base, file = base, dir = true }
      for name, type in vim.fs.dir(base, { depth = FOLDER_DEPTH }) do
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

local function folder_picker()
  Snacks.picker.pick({
    source = "folders",
    title = "Folders",
    finder = find_folders,
    format = "file",
    -- Change the tab's directory, then drop straight into the explorer there.
    -- tcd rather than cd so other tabs keep their own project.
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.cmd.tcd(vim.fn.fnameescape(item.file))
        Snacks.picker.explorer({ cwd = item.file })
      end
    end,
  })
end

return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            dev = DEV_ROOTS,
            -- Do not also scrape project roots out of recent-file history:
            -- with dev roots set correctly that only adds duplicates and
            -- one-off directories you opened a single file in.
            recent = false,
          },
        },
      },
    },
    keys = {
      { "<leader>fD", folder_picker, desc = "Folders (~/Documents)" },
    },
  },
}
