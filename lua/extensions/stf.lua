-- `swift-text-formatter`, outputting a .norg file to clipboard formatted text
-- Function to run 'stf' with the current file
local function run_stf()
    -- Get the current file's absolute path
    local file_path = vim.fn.expand('%:p')

    -- Run the 'stf' binary with the file path
    local output = vim.fn.system('stf ' .. file_path)

    -- Check for errors
    if vim.v.shell_error ~= 0 then
        vim.notify("stf failed: " .. output, vim.log.levels.ERROR)
    else
        vim.notify("Formatted text copied to clipboard.", vim.log.levels.INFO)
    end
end

-- Map the function to <leader>t
vim.keymap.set('n', '<leader>tf', run_stf, { noremap = true, silent = true })
-- text format 
