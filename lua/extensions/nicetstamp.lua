local M = {}

local header = require("extensions.niceheader")

---@class NicetstampState
---@field last_at table<string, number|nil>
M.State = { last_at = { split = nil, float = nil } }


M.config = {
    style     = "boxed",   -- "boxed" | "double" | "minimal"
    max_width = nil,       -- pass-through to niceheader (nil = auto)
    align     = "left",    -- "left" | "center" | "right"
    padding_l = 1,
    padding_r = 1,
    blank_after_header = true, -- insert a blank line between header and body
}

-- keep timers in Lua (not in b:) to avoid E5101 conversion errors
local uv = vim.uv or vim.loop
---@type table<integer, uv_timer_t?>
M._timers = setmetatable({}, { __mode = "v" }) -- weak values; timers won't leak

-- ---------- helpers ---------------------------------------------------------

---@param x any
---@return string[]
local function to_lines(x)
    if type(x) == "table" then return x end
    if type(x) == "string" then
        local t = {}
        for s in x:gmatch("([^\n]*)\n?") do t[#t+1] = s end
        return t
    end
    return { tostring(x) }
end

---@param sec number|nil
---@return string
local function humanize_ago(sec)
    local n = tonumber(sec or 0) or 0
    n = math.max(0, math.floor(n))
    local d = math.floor(n / 86400); n = n % 86400
    local h = math.floor(n / 3600);  n = n % 3600
    local m = math.floor(n / 60);    n = n % 60
    local s = n
    local parts = {}
    if d > 0 then parts[#parts+1] = d .. " day"   .. (d==1 and "" or "s") end
    if h > 0 then parts[#parts+1] = h .. " hour"  .. (h==1 and "" or "s") end
    if m > 0 then parts[#parts+1] = m .. " minute".. (m==1 and "" or "s") end
    if #parts == 0 then parts[#parts+1] = s .. " second"..(s==1 and "" or "s") end
    return table.concat(parts, ", ")
end

---@param ts number|nil
---@return string[] hdr_lines
local function build_header_lines(ts)
    local text = (type(ts) == "number")
    and ("output from " .. humanize_ago(os.time() - ts) .. " ago:")
    or  "output (time unknown)"

    if M.config.style == "minimal" then
        return { text }
    end

    return header.render(text, {
        style     = M.config.style,
        max_width = M.config.max_width,
        align     = M.config.align,
        padding_l = M.config.padding_l,
        padding_r = M.config.padding_r,
    })
end

---@param ts number|nil
---@return string
local function header_line(ts)
    if type(ts) ~= "number" then return "output (time unknown)" end
    local ago = humanize_ago(os.time() - ts)
    return "output from " .. ago .. " ago:"
end

-- ---------- public API ------------------------------------------------------

-----@param buf integer
-----@param ts number|nil
--function M.refresh_header(buf, ts)
--    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
--    local hdr = header_line(ts)
--    local prev_mod = vim.bo[buf].modifiable
--    vim.bo[buf].modifiable = true
--    local lc = vim.api.nvim_buf_line_count(buf)
--    if lc == 0 then
--        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { hdr })
--    else
--        vim.api.nvim_buf_set_lines(buf, 0, 1,  false, { hdr })
--    end
--    vim.bo[buf].modifiable = prev_mod
--end

-- function M.refresh_header(buf, ts)
--     if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
--     local hdr = build_header_lines(ts)

--     local prev_mod = vim.bo[buf].modifiable
--     vim.bo[buf].modifiable = true

--     -- how many header lines are currently in the buffer?
--     local n = tonumber(vim.b[buf].nicetstamp_hdr_n or 1) or 1
--     local lc = vim.api.nvim_buf_line_count(buf)

--     if lc == 0 then
--         vim.api.nvim_buf_set_lines(buf, 0, -1, false, hdr)
--     else
--         local endi = math.min(n, lc)
--         vim.api.nvim_buf_set_lines(buf, 0, endi, false, hdr)
--     end

--     -- store new header height
--     vim.b[buf].nicetstamp_hdr_n = #hdr + (M.config.blank_after_header and 1 or 0)

--     vim.bo[buf].modifiable = prev_mod
-- end

function M.refresh_header(buf, ts)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    local hdr = build_header_lines(ts)

    local prev_mod = vim.bo[buf].modifiable
    vim.bo[buf].modifiable = true

    -- how many header lines were previously written (default to current hdr size)
    local n_prev = tonumber(vim.b[buf].nicetstamp_hdr_n) or #hdr
    local lc = vim.api.nvim_buf_line_count(buf)

    if lc == 0 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, hdr)
    else
        local endi = math.min(n_prev, lc)  -- replace exactly previous header range
        vim.api.nvim_buf_set_lines(buf, 0, endi, false, hdr)
    end

    -- IMPORTANT: track ONLY header height (no blank separator)
    vim.b[buf].nicetstamp_hdr_n = #hdr

    vim.bo[buf].modifiable = prev_mod
end

---@param buf integer
---@param ts number
function M.set(buf, ts)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end
    if type(ts) ~= "number" then return end
    vim.b[buf].nicetstamp_ts = ts
    M.refresh_header(buf, ts)
end

---@param buf integer
---@return number|nil
function M.get(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return nil end
    local v = vim.b[buf].nicetstamp_ts
    return (type(v) == "number") and v or nil
end

-----@param lines string|string[]
-----@param ts number|nil
-----@return string[]
--function M.prepend_header(lines, ts)
--    local out = to_lines(lines)
--    table.insert(out, 1, header_line(ts))
--    return out
--end

-----@param lines string|string[]
-----@param ts number|nil
-----@param opts { force_blank?: boolean }|nil  -- set force_blank=true to always add a blank line
-----@return string[]
--function M.prepend_header(lines, ts, opts)
--    local body = to_lines(lines)
--    local has_body = false
--    -- consider there to be "body" if it's not empty and not just {""}
--    if #body > 1 then
--        has_body = true
--    elseif #body == 1 and body[1] ~= "" then
--        has_body = true
--    end

--    local out = { header_line(ts) }
--    if (opts and opts.force_blank) or has_body then
--        out[#out+1] = ""  -- the blank separator line
--    end
--    for i = 1, #body do
--        out[#out+1] = body[i]
--    end
--    return out
--end

-- function M.prepend_header(lines, ts, opts)
--     local body = to_lines(lines)
--     local has_body = (#body > 1) or (#body == 1 and body[1] ~= "")
--     local out = build_header_lines(ts)

--     local force_blank = opts and opts.force_blank
--     if force_blank or (M.config.blank_after_header and has_body) then
--         out[#out+1] = ""
--     end

--     for i = 1, #body do out[#out+1] = body[i] end
--     -- record header height for future refreshes
--     vim.b[vim.api.nvim_get_current_buf()].nicetstamp_hdr_n = (#out - #body)
--     return out
-- end

function M.prepend_header(lines, ts, opts)
    opts = opts or {}
    local body = to_lines(lines)
    local has_body = (#body > 1) or (#body == 1 and body[1] ~= "")

    local hdr = build_header_lines(ts)
    local out = {}
    for i = 1, #hdr do out[#out+1] = hdr[i] end

    local force_blank = opts.force_blank
    if force_blank or (M.config.blank_after_header and has_body) then
        out[#out+1] = ""
    end
    for i = 1, #body do out[#out+1] = body[i] end

    -- record ONLY header height on the **target** buffer
    local target_buf = opts.buf or vim.api.nvim_get_current_buf()
    if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
        vim.b[target_buf].nicetstamp_hdr_n = #hdr
    end

    return out
end

-- Stop/close + forget timer for a buffer (safe to call anytime).
---@param buf integer
function M.detach_autorefresh(buf)
    local t = M._timers[buf]
    if t and not t:is_closing() then
        t:stop()
        t:close()
    end
    M._timers[buf] = nil
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
    M._timers[buf] = timer

    local function tick()
        if not vim.api.nvim_buf_is_valid(buf) then
            M.detach_autorefresh(buf)
            return
        end
        local ts = M.get(buf)
        if ts and #vim.fn.win_findbuf(buf) > 0 then
            M.refresh_header(buf, ts)
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
