local funcs = require("config.funcs")

local notify = funcs.require_or_nil("notify", {
    message = "nvim-notify missing; using builtin notifications",
})

if not notify then
    return
end

vim.notify = notify

pcall(
    notify.setup, {
        stages = "static",
        timeout = 5000,
        background_colour = "#000000",
    }
)

-- -- Load the notify plugin
-- local notify = require("notify")

-- -- Set notify as the default notification handler
-- vim.notify = notify

-- -- Default settings for notifications
-- notify.setup({
--     stages = "static", -- Animation style: "fade", "slide", "fade_in_slide_out", "static"
--     timeout = 5000,  -- Default timeout for notifications (in ms)
--     background_colour = "#000000", -- Background color for notifications
-- })

-- -- Utility function for easier notifications
-- local function notify_message(message, level, opts)
--     opts = opts or {}
--     opts.title = opts.title or "Notification" -- Default title if not provided
--     vim.notify(message, level or vim.log.levels.INFO, opts)
-- end

-- -- Test function to simulate notifications
-- local function test_notifications()
--     local plugin = "Demo Plugin"

--     notify_message("This is an error message.\nSomething went wrong!", vim.log.levels.ERROR, {
--         title = plugin,
--         on_open = function()
--             notify_message("Attempting recovery.", vim.log.levels.WARN, { title = plugin })
--             local timer = vim.loop.new_timer()
--             timer:start(2000, 0, function()
--                 vim.schedule(function()
--                     notify_message({ "Fixing problem.", "Please wait..." }, vim.log.levels.INFO, {
--                         title = plugin,
--                         timeout = 3000,
--                         on_close = function()
--                             notify_message("Problem solved", vim.log.levels.INFO, { title = plugin })
--                             notify_message("Error code 0x0395AF", vim.log.levels.WARN, { title = plugin })
--                         end,
--                     })
--                 end)
--             end)
--         end,
--     })
-- end

-- -- Export the notify functions for other modules
-- return {
--     notify = notify_message,
--     test = test_notifications,
-- }
