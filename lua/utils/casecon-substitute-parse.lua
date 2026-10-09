-- Shared literal :S command parsing and preview match locations.
local M = {}

local function segment(input, position, delimiter)
    local parts = {}
    while position <= #input do
        local char = input:sub(position, position)
        if char == "\\" and position < #input then
            local following = input:sub(position + 1, position + 1)
            if following == delimiter or following == "\\" then
                parts[#parts + 1] = following
                position = position + 2
            else
                parts[#parts + 1] = char
                position = position + 1
            end
        elseif char == delimiter then
            return table.concat(parts), position + 1, true
        else
            parts[#parts + 1] = char
            position = position + 1
        end
    end
    return table.concat(parts), position, false
end

-- partial=true accepts an unfinished search for incremental highlighting.
function M.parse(input, partial)
    input = (input or ""):gsub("^%s+", "")
    local delimiter = input:sub(1, 1)
    if delimiter == "" or delimiter:match("[%w%s\\]") then
        return nil, "expected /needle/replacement/[g]"
    end

    local needle, position, search_closed = segment(input, 2, delimiter)
    if needle == "" then
        return nil, "nonempty search text is required"
    end
    if not search_closed then
        if partial then
            return { needle = needle, replacement = nil, global = true, stage = "search" }
        end
        return nil, "missing delimiter before replacement"
    end

    local replacement, after, replacement_closed = segment(input, position, delimiter)
    local flags = replacement_closed and vim.trim(input:sub(after)) or ""
    if flags ~= "" and flags ~= "g" then
        return nil, "only the g flag is supported"
    end

    return {
        needle = needle,
        replacement = replacement,
        global = flags == "g",
        stage = "replacement",
    }
end

-- ASCII-case-insensitive literal match positions for preview highlighting.
-- Swift casecon remains authoritative for the final Unicode-aware replacement.
function M.matches(line, needle, global)
    if needle == "" then return {} end
    local lowered = line:lower()
    local sought = needle:lower()
    local positions = {}
    local from = 1
    while from <= #line do
        local start_at, end_at = lowered:find(sought, from, true)
        if not start_at then break end
        positions[#positions + 1] = { start_at - 1, end_at }
        if not global then break end
        from = end_at + 1
    end
    return positions
end

return M
