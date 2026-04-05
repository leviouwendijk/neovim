local function insert_symbol(symbol_type)
    local symbols = {
        branch = "└── ",
        pointer = "└─> "
    }

    local symbol = symbols[symbol_type] or symbols.branch

    -- Get the current cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local line_number = cursor_pos[1] -- Get current line number (1-based index)

    -- Get the current line
    local current_line = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number, false)[1]

    -- Prepend the symbol symbol to the current line
    local new_text = symbol .. current_line

    -- Set the updated line in the buffer
    vim.api.nvim_buf_set_lines(0, line_number - 1, line_number, false, { new_text })

    vim.api.nvim_win_set_cursor(0, {line_number, #symbol})

    print(symbol .. " inserted at the beginning of the current line")
end

vim.api.nvim_create_user_command('Branch', function()
    insert_symbol("branch")
end, {})

vim.api.nvim_create_user_command('Pointer', function()
    insert_symbol("pointer")
end, {})
