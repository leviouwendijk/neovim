local M = {}

local niceheader = require("extensions.niceheader")

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
---@type table<integer, uv.uv_timer_t?>
M._timers = setmetatable({}, { __mode = "v" }) -- weak values; timers won't leak

local header = require("extensions.nicetstamp.header")({
    header = niceheader,
    config = M.config,
})

local buffer = require("extensions.nicetstamp.buffer")({
    config = M.config,
    header = header,
})

local autorefresh = require("extensions.nicetstamp.autorefresh")({
    uv = uv,
    timers = M._timers,
    buffer = buffer,
})

M.refresh_header = buffer.refresh_header
M.set = buffer.set
M.get = buffer.get
M.prepend_header = buffer.prepend_header
M.detach_autorefresh = autorefresh.detach_autorefresh
M.attach_autorefresh = autorefresh.attach_autorefresh

return M
