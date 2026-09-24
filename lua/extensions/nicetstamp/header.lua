return function(context)
    local M = {}
    local header = context.header
    local config = context.config

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

        if config.style == "minimal" then
            return { text }
        end

        return header.render(text, {
            style     = config.style,
            max_width = config.max_width,
            align     = config.align,
            padding_l = config.padding_l,
            padding_r = config.padding_r,
        })
    end

    ---@param ts number|nil
    ---@return string
    local function header_line(ts)
        if type(ts) ~= "number" then return "output (time unknown)" end
        local ago = humanize_ago(os.time() - ts)
        return "output from " .. ago .. " ago:"
    end

    M.to_lines = to_lines
    M.humanize_ago = humanize_ago
    M.build_header_lines = build_header_lines
    M.header_line = header_line

    return M
end
