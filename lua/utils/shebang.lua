local function insert_shebang()
    -- Map of file types to shebangs
    local shebang_map = {
        swift = "#!/usr/bin/swift",
        bash = "#!/usr/bin/bash",
        sh = "#!/usr/bin/sh",
        zsh = "#!/usr/bin/zsh",
        python = "#!/usr/bin/env python3",
        lua = "#!/usr/bin/env lua",
    }

    -- Get the current file type
    local filetype = vim.bo.filetype

    -- Check if the file type has a shebang defined
    local shebang = shebang_map[filetype]
    if not shebang then
        print("No shebang defined for filetype: " .. filetype)
        return
    end

    -- Prepend the shebang to the first line
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    table.insert(lines, 1, shebang)

    -- Set the updated lines back to the buffer
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    print("Shebang added: " .. shebang)
end

-- Expose the Lua function as a Vim function
vim.api.nvim_create_user_command('Shebang', function()
    insert_shebang()
end, {})
