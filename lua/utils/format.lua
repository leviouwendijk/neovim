local log = require("core.log")
local list = require("utils.format.list")
local comma_list =
    require("utils.format.comma-list")
local swift_function =
    require("utils.format.swift-function")

-- Main function to format selected lines individually with indentation
function FormatList(range)
    log.log("")
    log.log("================START================")
    local start_line = range.line1
    local end_line = range.line2

    local lines = vim.fn.getline(start_line, end_line)
    local formatted_lines =
        list.format(lines)

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, formatted_lines)
    log.copy_log_to_clipboard()
    log.log("================END================")
    log.log("")
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

    local formatted_lines =
        comma_list.format(
            lines,
            base_indent
        )

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

    local formatted_lines =
        swift_function.format(
            lines,
            base_indent
        )

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
