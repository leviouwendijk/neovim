-- Global variable to track the last copied message
_G.last_copied_message = nil

-- Function to copy all messages
function _G.copy_all_messages_to_clipboard()
    -- Retrieve all messages
    local messages = vim.fn.execute("messages")
    
    -- Copy to the system clipboard
    vim.fn.setreg("+", messages)
    
    print("All messages copied to clipboard!")
end

-- Function to copy only new messages since the last call
function _G.copy_latest_messages_to_clipboard()
    -- Retrieve all messages
    local messages = vim.fn.execute("messages")
    
    -- Split messages into lines
    local lines = vim.split(messages, "\n", { trimempty = true })
    
    -- Find the last copied message in the current output
    local new_messages = {}
    local found_last = _G.last_copied_message == nil
    
    for _, line in ipairs(lines) do
        if found_last then
            table.insert(new_messages, line)
        elseif line == _G.last_copied_message then
            found_last = true
        end
    end

    -- If no new messages, inform the user and return
    if #new_messages == 0 then
        print("No new messages to copy.")
        return
    end

    -- Update the last copied message
    _G.last_copied_message = lines[#lines]
    
    -- Join the new messages and copy to the system clipboard
    local new_messages_str = table.concat(new_messages, "\n")
    vim.fn.setreg("+", new_messages_str)
    
    print("New messages copied to clipboard!")
end

-- Key mapping for copying all messages
vim.api.nvim_set_keymap(
    "n",
    "<leader>cma",
    ":lua copy_all_messages_to_clipboard()<CR>",
    { noremap = true, silent = true }
)

-- Key mapping for copying latest messages
vim.api.nvim_set_keymap(
    "n",
    "<leader>cml",
    ":lua copy_latest_messages_to_clipboard()<CR>",
    { noremap = true, silent = true }
)
