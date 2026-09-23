-- Feed test results to the activity bar's Testing badge
-- (lua/config/activitybar.lua). LazyVim's test.core extra does the rest.
return {
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      consumers = {
        activitybar = function(client)
          return require("config.activitybar").neotest_consumer(client)
        end,
      },
    },
  },
}
