local M = {}

---@class NiceHeaderConfig
---@field style        '"boxed"'|'"double"'|'"minimal"'  -- border style
---@field max_width    integer|nil                        -- total width of box (auto if nil)
---@field padding_l    integer                            -- content left padding
---@field padding_r    integer                            -- content right padding
---@field align        '"left"'|'"center"'|'"right"'

M.config = {
    style     = "boxed",
    max_width = nil,     -- nil = autosize to content
    padding_l = 1,
    padding_r = 1,
    align     = "left",
}

local fn = vim.fn
local function dispw(s) return fn.strdisplaywidth(s) end

-- local function wrap_words(text, limit)
--     if limit <= 0 then return { text } end
--     local out, line, wlen = {}, "", 0
--     for word in tostring(text):gmatch("%S+") do
--         local ww = dispw(word)
--         if wlen == 0 then
--             line, wlen = word, ww
--         elseif (wlen + 1 + ww) <= limit then
--             line, wlen = (line .. " " .. word), (wlen + 1 + ww)
--         else
--             out[#out+1] = line
--             line, wlen = word, ww
--         end
--     end
--     if line ~= "" then out[#out+1] = line end
--     if #out == 0 then out[1] = "" end
--     return out
-- end

-- -- testing preservation of newlines
-- local function wrap_words(text, limit)
--     -- Preserve manual newlines: wrap each paragraph separately.
--     local paras = {}
--     for seg in tostring(text):gmatch("([^\n]*)\n?") do
--         if seg == "" then
--             table.insert(paras, { "" }) -- blank line between paragraphs
--         else
--             local out, line, wlen = {}, "", 0
--             for word in seg:gmatch("%S+") do
--                 local ww = dispw(word)
--                 if wlen == 0 then
--                     line, wlen = word, ww
--                 elseif (wlen + 1 + ww) <= limit then
--                     line, wlen = (line .. " " .. word), (wlen + 1 + ww)
--                 else
--                     out[#out+1] = line
--                     line, wlen = word, ww
--                 end
--             end
--             if line ~= "" then out[#out+1] = line end
--             if #out == 0 then out[1] = "" end
--             table.insert(paras, out)
--         end
--     end
--     -- flatten + collapse double blanks
--     local flat = {}
--     for i, p in ipairs(paras) do
--         for _, s in ipairs(p) do flat[#flat+1] = s end
--         if i < #paras then flat[#flat+1] = "" end
--     end
--     if #flat == 0 then flat[1] = "" end
--     return flat
-- end

-- Preserve explicit newlines, wrap each line independently, and do NOT
-- inject extra blank lines between paragraphs.
local function wrap_words(text, limit)
    limit = tonumber(limit) or 0
    if limit <= 0 then return { tostring(text) } end

    local out = {}
    for src in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        if src == "" then
            out[#out+1] = ""  -- keep explicit blank line
        else
            local line, wlen = "", 0
            for word in src:gmatch("%S+") do
                local ww = dispw(word)
                if wlen == 0 then
                    line, wlen = word, ww
                elseif (wlen + 1 + ww) <= limit then
                    line, wlen = (line .. " " .. word), (wlen + 1 + ww)
                else
                    out[#out+1] = line
                    line, wlen = word, ww
                end
            end
            if line ~= "" then out[#out+1] = line end
        end
    end
    if #out == 0 then out[1] = "" end
    return out
end

local borders = {
    boxed  = { tl="┌", tr="┐", bl="└", br="┘", h="─", v="│" },
    double = { tl="╔", tr="╗", bl="╚", br="╝", h="═", v="║" },
}

---@param text string
---@param opts NiceHeaderConfig|nil
---@return string[] lines
function M.render(text, opts)
    opts = opts and vim.tbl_deep_extend("force", M.config, opts) or M.config
    if opts.style == "minimal" then
        return { text }
    end

    local b   = borders[opts.style] or borders.boxed
    local pl  = tonumber(opts.padding_l or 1) or 1
    local pr  = tonumber(opts.padding_r or 1) or 1

    -- If max_width is nil, autosize box to content width.
    local content_limit
    if opts.max_width and opts.max_width > 4 + pl + pr then
        content_limit = opts.max_width - (2 + pl + pr)
    else
        content_limit = math.max(1, dispw(text))
    end

    local wrapped = wrap_words(text, content_limit)

    -- compute inner width (max of wrapped lines)
    local inner_w = 0
    for _, s in ipairs(wrapped) do inner_w = math.max(inner_w, dispw(s)) end

    local top    = b.tl .. string.rep(b.h, pl + inner_w + pr) .. b.tr
    local bottom = b.bl .. string.rep(b.h, pl + inner_w + pr) .. b.br

    -- alignment
    local function pad_line(s)
        local w = dispw(s)
        local left, right = pl, pr
        if opts.align == "center" then
            local extra = inner_w - w
            left  = pl + math.floor(extra/2)
            right = pr + (extra - math.floor(extra/2))
        elseif opts.align == "right" then
            left  = pl + (inner_w - w)
            right = pr
        else
            right = pr + (inner_w - w)
        end
        return b.v .. string.rep(" ", left) .. s .. string.rep(" ", right) .. b.v
    end

    local lines = { top }
    for _, s in ipairs(wrapped) do lines[#lines+1] = pad_line(s) end
    lines[#lines+1] = bottom
    return lines
end

return M
