local confirm = require("core.confirm")

-- Function to perform chmod 600 on a specific file or directory
local function perform_chmod(file)
    if file == '' then
        print("No file to restrict")
        return
    end

    -- Check if the path is a directory
    if vim.fn.isdirectory(file) == 1 then
        local filename = vim.fn.fnamemodify(file, ':t') -- Get only the name
        if not confirm.confirm_action("The target is a directory: " .. filename .. ". Proceed?") then
            print("Aborted chmod 600 on directory: " .. filename)
            return
        end
    end

    -- Execute chmod 600
    local success = os.execute('chmod 600 ' .. vim.fn.shellescape(file))
    if success then
        print("chmod 600 applied to > " .. vim.fn.fnamemodify(file, ':t')) -- Show only filename
    else
        print("Failed to apply chmod 600 to > " .. vim.fn.fnamemodify(file, ':t'))
    end
end

-- Function to handle chmod 600 when inside a buffer
local function chmod_in_buffer()
    local filename = vim.fn.expand('%') -- Get the current file name
    if vim.fn.empty(filename) == 1 then
        print("No file loaded in the buffer")
        return
    end
    perform_chmod(filename)
end

-- Function to handle chmod 600 when inside netrw
local function chmod_in_netrw()
    local netrw_file = vim.fn.expand('<cfile>') -- Get the file under the cursor in netrw
    if vim.fn.empty(netrw_file) == 1 then
        print("No file under the cursor in netrw")
        return
    end
    perform_chmod(netrw_file)
end

-- Main chmod600 function to determine context and execute the appropriate logic
local function chmod600()
    if vim.bo.filetype == 'netrw' then
        chmod_in_netrw() -- Handle netrw context
    else
        chmod_in_buffer() -- Handle buffer context
    end
end

-- Create the user command "Restrict"
vim.api.nvim_create_user_command("Restrict", chmod600, { desc = "Restrict file permissions to 600" })
