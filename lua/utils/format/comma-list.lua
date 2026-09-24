local M = {}

-- Format comma-separated lists (arrays, sets, dictionaries)
local function format_comma_list(lines, base_indent)
    local formatted = {}

    -- Step 1: Merge multi-line declarations
    local merged_lines = {}
    local current_line = nil
    local line_indent = nil
    local brace_depth = 0

    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")

        if not current_line then
            -- Start of a new statement
            line_indent = line:match("^(%s*)") or ""
            current_line = trimmed

            -- Count braces/brackets
            for char in trimmed:gmatch(".") do
                if char == "[" or char == "{" then
                    brace_depth = brace_depth + 1
                elseif char == "]" or char == "}" then
                    brace_depth = brace_depth - 1
                end
            end
        else
            -- Continue current statement
            current_line = current_line .. " " .. trimmed

            -- Update brace depth
            for char in trimmed:gmatch(".") do
                if char == "[" or char == "{" then
                    brace_depth = brace_depth + 1
                elseif char == "]" or char == "}" then
                    brace_depth = brace_depth - 1
                end
            end
        end

        -- If braces are balanced, we have a complete statement
        if brace_depth == 0 and current_line then
            table.insert(merged_lines, {text = current_line, indent = line_indent})
            current_line = nil
            line_indent = nil
        end
    end

    -- Add any remaining line
    if current_line then
        table.insert(merged_lines, {text = current_line, indent = line_indent})
    end

    -- Step 2: Process each merged line
    for _, line_data in ipairs(merged_lines) do
        local line = line_data.text
        local line_indent = line_data.indent or base_indent

        -- Check if line contains array/set/dict initialization
        if line:match("[%[{]") then
            -- Find the opening brace/bracket and what comes before/after
            local before_open, open_char, content, close_char, after_close

            -- Try to match array/set pattern [...]
            before_open, content, after_close = line:match("^(.-)%[(.-)%](.*)$")
            if before_open then
                open_char, close_char = "[", "]"
            else
                -- Try to match dictionary pattern {...}
                before_open, content, after_close = line:match("^(.-)%{(.-)%}(.*)$")
                if before_open then
                    open_char, close_char = "{", "}"
                end
            end

            if before_open and content then
                -- Split content by comma (respecting nested structures)
                local items = {}
                local current_item = ""
                local depth = 0

                for char in content:gmatch(".") do
                    if char == "[" or char == "{" or char == "(" then
                        depth = depth + 1
                        current_item = current_item .. char
                    elseif char == "]" or char == "}" or char == ")" then
                        depth = depth - 1
                        current_item = current_item .. char
                    elseif char == "," and depth == 0 then
                        local trimmed = current_item:match("^%s*(.-)%s*$")
                        if trimmed and trimmed ~= "" then
                            table.insert(items, trimmed)
                        end
                        current_item = ""
                    else
                        current_item = current_item .. char
                    end
                end

                -- Add last item
                local trimmed = current_item:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    table.insert(items, trimmed)
                end

                -- Format based on number of items
                if #items <= 1 then
                    -- Keep single-item lists inline
                    table.insert(formatted, line_indent .. line)
                else
                    -- Multi-item: expand to multiple lines
                    table.insert(formatted, line_indent .. before_open .. open_char)

                    for i, item in ipairs(items) do
                        local comma = (i < #items) and "," or ""
                        table.insert(formatted, line_indent .. "    " .. item .. comma)
                    end

                    table.insert(formatted, line_indent .. close_char .. after_close)
                end
            else
                -- Couldn't parse, keep original
                table.insert(formatted, line_indent .. line)
            end
        else
            -- No braces/brackets, keep as-is
            table.insert(formatted, line_indent .. line)
        end
    end

    return formatted
end

M.format = format_comma_list

return M
