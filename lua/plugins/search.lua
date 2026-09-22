-- Find and replace from the grep picker, like VSCode's search panel.
-- Keys are also documented by hand in lua/config/cheatsheet_data.lua -- see README.md.
--
-- <A-r> in any grep picker (<leader>/, <leader>sg, the activity bar's Search
-- icon) closes it and opens grug-far (LazyVim's find-and-replace panel, also
-- on <leader>sr) with the same search text and folder filled in. Type the
-- replacement there and apply it across the project.
local function replace(picker)
  local search = picker:filter().search
  if search == "" then
    search = picker.input:get()
  end
  local cwd = picker:cwd()
  picker:close()
  require("grug-far").open({
    transient = true,
    prefills = { search = search, paths = cwd },
  })
end

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        grep = {
          title = "Grep  (Alt-r: replace)",
          actions = { grep_replace = { action = replace, desc = "Find and replace" } },
          win = {
            input = { keys = { ["<a-r>"] = { "grep_replace", mode = { "n", "i" } } } },
            list = { keys = { ["<a-r>"] = "grep_replace" } },
          },
        },
      },
    },
  },
}
