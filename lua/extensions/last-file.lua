local function write_path_and_line(file_path, line)
    -- Define file paths for .memory and .line
    local memory_file_path = vim.fn.expand("~/.zsh-extensions/last-file/components/.memory")
    local line_file_path = vim.fn.expand("~/.zsh-extensions/last-file/components/.line")
    local max_history = 10 -- Maximum history size

    if file_path ~= "" then
        -- Read existing data from .memory and .line
        local memory_lines, line_numbers = {}, {}
        local file = io.open(memory_file_path, "r")
        if file then
            for line in file:lines() do
                table.insert(memory_lines, line)
            end
            file:close()
        end

        file = io.open(line_file_path, "r")
        if file then
            for line in file:lines() do
                table.insert(line_numbers, line)
            end
            file:close()
        end

        -- Insert the new entry at the top
        table.insert(memory_lines, 1, file_path)
        table.insert(line_numbers, 1, line or 1)

        -- Enforce maximum history size
        while #memory_lines > max_history do
            table.remove(memory_lines) -- Remove the oldest entry
        end
        while #line_numbers > max_history do
            table.remove(line_numbers) -- Remove the oldest entry
        end

        -- Write updated data back to .memory and .line
        local out_file = io.open(memory_file_path, "w")
        if out_file then
            for _, memory_line in ipairs(memory_lines) do
                out_file:write(memory_line .. "\n")
            end
            out_file:close()
        end

        out_file = io.open(line_file_path, "w")
        if out_file then
            for _, line_number in ipairs(line_numbers) do
                out_file:write(line_number .. "\n")
            end
            out_file:close()
        end
    end
end

-- Hook into BufLeave to save the current line
vim.api.nvim_create_autocmd("BufLeave", {
    callback = function()
        local file_path = vim.fn.expand("%:p")
        if file_path ~= "" then
            local current_line = vim.fn.line(".")
            write_path_and_line(file_path, current_line)
        end
    end,
})

-- Hook into BufReadPost to log the file path
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local file_path = vim.fn.expand("%:p")
        write_path_and_line(file_path, vim.fn.line("."))
    end,
})
