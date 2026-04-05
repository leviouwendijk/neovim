local json = {}

-- Escape sequences for encoding
local escape_char_map = {
    ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b",
    ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"
}

local function encode_string(str)
    return '"' .. str:gsub('[%z\1-\31\\"]', escape_char_map) .. '"'
end

local function encode_table(val, depth)
    local is_array = (#val > 0)
    local result = {}

    if is_array then
        for _, v in ipairs(val) do
            table.insert(result, json.encode(v, depth + 1))
        end
        return "[" .. table.concat(result, ",") .. "]"
    else
        for k, v in pairs(val) do
            if type(k) == "string" then
                table.insert(result, encode_string(k) .. ":" .. json.encode(v, depth + 1))
            end
        end
        return "{" .. table.concat(result, ",") .. "}"
    end
end

function json.encode(val, depth)
    depth = depth or 0
    if type(val) == "string" then return encode_string(val) end
    if type(val) == "number" or type(val) == "boolean" then return tostring(val) end
    if type(val) == "table" then return encode_table(val, depth) end
    return "null"
end

local function decode_error(pos, msg)
    error("JSON decode error at position " .. pos .. ": " .. msg)
end

local function parse_value(str, pos)
    -- Skip leading whitespace
    pos = str:match("^%s*", pos):len() + pos
    local char = str:sub(pos, pos)

    if char == "{" then
        local obj, new_pos = {}, pos + 1
        while true do
            new_pos = str:match("^%s*", new_pos):len() + new_pos
            char = str:sub(new_pos, new_pos)
            if char == "}" then return obj, new_pos + 1 end
            local key, value
            key, new_pos = parse_value(str, new_pos)
            new_pos = str:match("^%s*", new_pos):len() + new_pos
            if str:sub(new_pos, new_pos) ~= ":" then decode_error(new_pos, "Expected ':'") end
            value, new_pos = parse_value(str, new_pos + 1)
            obj[key] = value
            new_pos = str:match("^%s*", new_pos):len() + new_pos
            char = str:sub(new_pos, new_pos)
            if char == "}" then return obj, new_pos + 1 end
            if char ~= "," then decode_error(new_pos, "Expected ','") end
            new_pos = new_pos + 1
        end
    elseif char == "[" then
        local arr, new_pos = {}, pos + 1
        while true do
            new_pos = str:match("^%s*", new_pos):len() + new_pos
            char = str:sub(new_pos, new_pos)
            if char == "]" then return arr, new_pos + 1 end
            local value
            value, new_pos = parse_value(str, new_pos)
            table.insert(arr, value)
            new_pos = str:match("^%s*", new_pos):len() + new_pos
            char = str:sub(new_pos, new_pos)
            if char == "]" then return arr, new_pos + 1 end
            if char ~= "," then decode_error(new_pos, "Expected ','") end
            new_pos = new_pos + 1
        end
    elseif char == "\"" then
        local new_pos = pos + 1
        local result = ""
        while true do
            char = str:sub(new_pos, new_pos)
            if char == "\\" then
                -- Handle escape sequences properly
                local next_char = str:sub(new_pos + 1, new_pos + 1)
                local escape_map = {
                    ["\\"] = "\\", ["\""] = "\"", ["b"] = "\b",
                    ["f"] = "\f", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
                }
                result = result .. (escape_map[next_char] or next_char)
                new_pos = new_pos + 2
            elseif char == "\"" then
                return result, new_pos + 1
            else
                result = result .. char
                new_pos = new_pos + 1
            end
        end
    elseif char:match("[%d%-]") then
        local num = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        return tonumber(num), pos + #num
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    end
    decode_error(pos, "Unexpected character: " .. char)
end

function json.decode(str)
    local val, pos = parse_value(str, 1)
    return val
end

return json
