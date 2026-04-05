local log = require("core.log")

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

-- Main function to format selected lines individually with indentation
function FormatList(range)
    log.log("")
    log.log("================START================")
    local start_line = range.line1
    local end_line = range.line2

    local lines = vim.fn.getline(start_line, end_line)
    local formatted_lines = {}

    for _, line in ipairs(lines) do
        local indent_level, base_indent = detect_indentation(line)
        local structure = detect_structure(line)

        if structure == "array" then
            vim.list_extend(formatted_lines, format_array_line(line, indent_level, base_indent))
        elseif structure == "dictionary" then
            vim.list_extend(formatted_lines, format_dictionary_line(line, indent_level, base_indent))
        else
            vim.list_extend(formatted_lines, format_inline_line(line))
        end
    end

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, formatted_lines)
    log.copy_log_to_clipboard()
    log.log("================END================")
    log.log("")
end

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

-- Main function to format comma-separated lists
function FormatCommaList(range)
    log.log("")
    log.log("================START COMMA LIST================")

    local start_line = range.line1
    local end_line = range.line2

    local lines = vim.fn.getline(start_line, end_line)

    -- Detect base indentation from first line
    local first_line = lines[1] or ""
    local base_indent = first_line:match("^(%s*)") or ""

    log.log("Base indent detected: " .. string.rep(".", #base_indent))

    local formatted_lines = format_comma_list(lines, base_indent)

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, formatted_lines)

    log.copy_log_to_clipboard()
    log.log("================END COMMA LIST================")
    log.log("")
end

-- Main function to format Swift functions
function FormatSwiftFunc(range)
    log.log("")
    log.log("================START SWIFT FUNC================")

    local start_line = range.line1
    local end_line = range.line2

    local lines = vim.fn.getline(start_line, end_line)

    -- Detect base indentation from first line
    local first_line = lines[1] or ""
    local base_indent = first_line:match("^(%s*)") or ""

    log.log("Base indent detected: " .. string.rep(".", #base_indent))

    local formatted_lines = format_swift_function(lines, base_indent)

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, formatted_lines)

    log.copy_log_to_clipboard()
    log.log("================END SWIFT FUNC================")
    log.log("")
end

-- Update FormatAuto to detect comma lists
function FormatAuto(range)
    local start_line = range.line1
    local end_line = range.line2
    local lines = vim.fn.getline(start_line, end_line)

    -- Check what type of formatting is needed
    local has_func = false
    local has_list = false

    for _, line in ipairs(lines) do
        if line:match("func%s+") then
            has_func = true
            break
        elseif line:match("[%[{].-,.*[%]}]") then
            has_list = true
        end
    end

    if has_func then
        FormatSwiftFunc(range)
    elseif has_list then
        FormatCommaList(range)
    else
        FormatList(range)
    end
end


vim.api.nvim_create_user_command("FormatAuto", FormatAuto, { range = true })
vim.api.nvim_create_user_command("FormatSwiftFunc", FormatSwiftFunc, { range = true })
vim.api.nvim_create_user_command("FormatCommaList", FormatCommaList, { range = true })

vim.keymap.set("v", "<leader>fc", ":FormatCommaList<CR>", { silent = true })
vim.keymap.set("v", "<leader>ff", ":FormatSwiftFunc<CR>", { silent = true })
vim.keymap.set("v", "<leader>fa", ":FormatAuto<CR>", { silent = true })

vim.api.nvim_create_user_command("FormatList", FormatList, { range = true })
