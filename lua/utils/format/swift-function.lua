local M = {}

local function format_swift_function(lines, base_indent)
    local formatted = {}

    -- Step 1: Merge multi-line function declarations into single lines
    local merged_lines = {}
    local current_func = nil
    local func_indent = nil

    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")

        -- Check if this starts a function declaration
        if trimmed:match("^[^/]*func%s+") then
            func_indent = line:match("^(%s*)") or ""
            current_func = trimmed
        -- Check if we're continuing a function (no closing brace yet)
        elseif current_func and not current_func:match("%{%s*$") then
            current_func = current_func .. " " .. trimmed
        else
            -- If we have a complete function, add it
            if current_func then
                table.insert(merged_lines, {text = current_func, indent = func_indent})
                current_func = nil
                func_indent = nil
            end
            -- Add non-function lines as-is
            if not trimmed:match("^%s*$") then
                local line_indent = line:match("^(%s*)") or ""
                table.insert(merged_lines, {text = trimmed, indent = line_indent})
            end
        end
    end

    -- Add final function if exists
    if current_func then
        table.insert(merged_lines, {text = current_func, indent = func_indent})
    end

    -- Step 2: Process each merged line
    for _, line_data in ipairs(merged_lines) do
        local line = line_data.text
        local line_indent = line_data.indent or base_indent

        -- Check if line contains a function declaration
        if line:match("^[^/]*func%s+") then
            -- Extract parts: everything before '(', arguments, everything after ')'                                                 
            local before_paren = line:match("^(.-)%(")
            local after_close = line:match("%)(.*)$")
            local args_section = line:match("%((.-)%)")

            if before_paren and args_section and after_close then                                                                        -- Start function declaration
                table.insert(formatted, line_indent .. before_paren .. "(")
                local args = {}
                local current_arg = ""
                local depth = 0

                -- Split arguments by comma (handling nested generics/defaults)
                for char in args_section:gmatch(".") do
                    if char == "<" or char == "(" or char == "[" then
                        depth = depth + 1
                        current_arg = current_arg .. char
                    elseif char == ">" or char == ")" or char == "]" then
                        depth = depth - 1
                        current_arg = current_arg .. char
                    elseif char == "," and depth == 0 then
                        local trimmed_arg = current_arg:match("^%s*(.-)%s*$")
                        if trimmed_arg and trimmed_arg ~= "" then
                            table.insert(args, trimmed_arg)
                        end
                        current_arg = ""
                    else
                        current_arg = current_arg .. char
                    end
                end

                -- Add last argument
                local trimmed_arg = current_arg:match("^%s*(.-)%s*$")
                if trimmed_arg and trimmed_arg ~= "" then
                    table.insert(args, trimmed_arg)
                end

                -- Add each argument on its own line
                for i, arg in ipairs(args) do
                    local comma = (i < #args) and "," or ""
                    table.insert(formatted, line_indent .. "    " .. arg .. comma)
                end

                -- Close function declaration with proper formatting
                table.insert(formatted, line_indent .. ")" .. after_close)
            else
                -- Couldn't parse, keep original
                table.insert(formatted, line_indent .. line)
            end
        else
            -- Not a function line, keep as-is
            table.insert(formatted, line_indent .. line)
        end
    end

    return formatted
end

M.format = format_swift_function

return M
