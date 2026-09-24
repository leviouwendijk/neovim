return function(context)
    local M = {}
    local uv = context.uv
    local timers = context.timers
    local buffer = context.buffer

    -- Stop/close + forget timer for a buffer (safe to call anytime).
    ---@param buf integer
    function M.detach_autorefresh(buf)
        local t = timers[buf]
        if t and not t:is_closing() then
            t:stop()
            t:close()
        end
        timers[buf] = nil
    end

    ---@param buf integer
    ---@param period_seconds number|nil
    function M.attach_autorefresh(buf, period_seconds)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
        local period = tonumber(period_seconds or 5) or 5

        -- stop an existing timer for this buf (if any)
        M.detach_autorefresh(buf)

        local timer = uv.new_timer()
        if not timer then return end
        timers[buf] = timer

        local function tick()
            if not vim.api.nvim_buf_is_valid(buf) then
                M.detach_autorefresh(buf)
                return
            end
            local ts = buffer.get(buf)
            if ts and #vim.fn.win_findbuf(buf) > 0 then
                buffer.refresh_header(buf, ts)
            end
        end

        timer:start(period * 1000, period * 1000, vim.schedule_wrap(tick))

        -- refresh when shown
        vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
            buffer = buf,
            callback = tick,
            desc = "nicetstamp: refresh header on show",
        })

        -- cleanup on buffer end-of-life
        vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
            buffer = buf,
            callback = function() M.detach_autorefresh(buf) end,
            desc = "nicetstamp: cleanup timer",
        })
    end

    return M
end
