local M = {}

local function ensure_notify()
    local ok, notify = pcall(require, "notify")
    if ok and vim.notify ~= notify then
        vim.notify = notify
    end
    return ok
end

-- -- util: safe, scheduled notify (no hit-enter) with optional opts
-- -- usage: Utils.safe_notify("msg") or Utils.safe_notify("oops", vim.log.levels.ERROR, { timeout = 1500 })
-- function M.safe_notify(msg, level, opts)
--     ensure_notify() -- harmless if nvim-notify isn't installed yet
--     vim.schedule(function()
--         -- pcall to avoid blowing up if a UI is missing
--         pcall(vim.notify, msg, level or vim.log.levels.INFO, opts or { timeout = 1200 })
--     end)
-- end

local function call(msg, level, opts)
    ensure_notify()
    vim.schedule(function()
        pcall(vim.notify, msg, level or vim.log.levels.INFO, opts or { timeout = 1200 })
    end)
end

M.safe_notify = call
M.info  = function(m,o) call(m, vim.log.levels.INFO,  o) end
M.warn  = function(m,o) call(m, vim.log.levels.WARN,  o) end
M.warning  = function(m,o) call(m, vim.log.levels.WARN,  o) end
M.error = function(m,o) call(m, vim.log.levels.ERROR, o) end
M.debug = function(m,o) call(m, vim.log.levels.DEBUG, o) end

M.debug_when = function(condition, m,o)
    if condition then
        call(m, vim.log.levels.DEBUG, o)
    end
end

return M
