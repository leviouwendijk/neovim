local log = require("core.log")

local M = {}

-- Default indentation size (4 spaces)
local INDENT_SIZE = 4

-- Function to detect the indentation level of a line
local function detect_indentation(line)
    local leading_spaces = line:match("^(%s*)") or ""
    local indent_level = math.floor(#leading_spaces / INDENT_SIZE)
    log.log("Detected indentation level: " .. indent_level .. " for line: " .. line)
    return indent_level, leading_spaces
end

-- Detect if a line contains an array, dictionary, or inline structure
local function detect_structure(line)
    local structure
    if line:find("%[") then
        structure = "array"
    elseif line:find("{") then
        structure = "dictionary"
    else
        structure = "inline"
    end
    log.log("Detected structure: " .. structure .. " - Line: " .. line)
    return structure
end

-- Format arrays with correct indentation
local function format_array_line(line, indent_level, base_indent)
    log.log("Formatting array line at level " .. indent_level .. ": " .. line)

    local indent_str = base_indent -- Keep original indentation
    local value_indent = base_indent .. string.rep(" ", INDENT_SIZE * 1) -- Fix: Adjust indent

    -- -- Debugging outputs to check indent calculations
    -- local debug_base = string.rep(".", #base_indent)
    -- log.log("debug base: " .. debug_base)
    -- local debug_indent_str = string.rep(".", INDENT_SIZE * indent_level)
    -- log.log("debug indent str: " .. debug_indent_str)
    -- local debug_value_indent_str = string.rep(".", INDENT_SIZE * (indent_level + 1))
    -- log.log("debug value indent str: " .. debug_value_indent_str)

    -- Format array structure with correct indentation
    line = line:gsub("%[", "[\n" .. value_indent)
    line = line:gsub("%]", "\n" .. indent_str .. "]")
    line = line:gsub(",%s*", ",\n" .. value_indent)

    local result = vim.split(line, "\n", { plain = true })
    log.log("Formatted array result:\n" .. table.concat(result, "\n"))
    return result
end

-- Format dictionaries with correct indentation
local function format_dictionary_line(line, indent_level, base_indent)
    log.log("Formatting dictionary line at level " .. indent_level .. ": " .. line)

    local indent_str = base_indent .. string.rep(" ", INDENT_SIZE * indent_level)
    local value_indent = base_indent .. string.rep(" ", INDENT_SIZE * (indent_level + 1)) -- Adjusted here

    -- Format dictionary structure with correct indentation
    line = line:gsub("{%s*", "{\n" .. value_indent)
    line = line:gsub("%s*}", "\n" .. indent_str .. "}")

    -- Format nested dictionaries within the same line
    line = line:gsub("{(.-)}", function(inner_content)
        inner_content = inner_content:gsub(",%s*", ",\n" .. base_indent .. string.rep(" ", INDENT_SIZE * (indent_level + 2)))
        return "{\n" .. base_indent .. string.rep(" ", INDENT_SIZE * (indent_level + 2)) .. inner_content .. "\n" .. value_indent .. "}"
    end)

    -- Format each key-value pair in the dictionary
    line = line:gsub(",%s*", ",\n" .. value_indent)
    line = line:gsub("%s*:%s*", ": ")

    local result = vim.split(line, "\n", { plain = true })
    log.log("Formatted dictionary result:\n" .. table.concat(result, "\n"))
    return result
end

-- Inline formatting to preserve small structures within braces
local function format_inline_line(line)
    log.log("Formatting inline line: " .. line)
    line = line:gsub("(%b{})", function(match)
        if match:find(",") then
            return match
        else
            return match:gsub("%s+", " ")
        end
    end)
    log.log("Formatted inline result: " .. line)
    return { line }
end

function M.format(lines)
    local formatted_lines = {}

    for _, line in ipairs(lines) do
        local indent_level, base_indent = detect_indentation(line)
        local structure = detect_structure(line)

        if structure == "array" then
            vim.list_extend(
                formatted_lines,
                format_array_line(
                    line,
                    indent_level,
                    base_indent
                )
            )
        elseif structure == "dictionary" then
            vim.list_extend(
                formatted_lines,
                format_dictionary_line(
                    line,
                    indent_level,
                    base_indent
                )
            )
        else
            vim.list_extend(
                formatted_lines,
                format_inline_line(line)
            )
        end
    end

    return formatted_lines
end

return M
