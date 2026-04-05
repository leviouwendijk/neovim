local Path = require('plenary.path')

-- Define the directory containing reusable code files
local core_dir = vim.fn.expand("~/myworkdir/programming/.reusable/")
local sub_dir = ""
local reusable_dir = core_dir .. sub_dir

local function insert_file_content(filepath)
    -- local filepath = reusable_dir .. filename
    -- replaced entry.value with full path, so no need to prepend the dir
    local file = io.open(filepath, "r")
    if file then
        -- Read the file contents and close
        local content = file:read("*a")
        file:close()

        -- Split content by newlines and keep empty lines exactly as they are
        local lines = vim.split(content, "\n", true)

        -- Insert each line individually to preserve formatting exactly as in the file
        vim.api.nvim_put(lines, "l", true, true)
    else
        print("Could not open file: " .. filepath)
    end
end

-- Function to recursively gather files from all subdirectories within reusable_dir
local function list_files_in_dir(dir, root)
    local files = {}
    local handle = vim.loop.fs_scandir(dir)

    if not handle then
        print("Reusable directory does not exist or cannot be read")
        return files
    end

    while true do
        local name, type = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local full_path = dir .. "/" .. name

        -- Skip dotfiles at this stage to avoid an initial flood of hidden files
        if name:sub(1, 1) ~= "." then
            local relative_path = full_path:sub(#root + 2) -- Strip root directory path, including trailing "/"

            -- Add the file directly or recurse if it's a directory
            if type == "file" then
                table.insert(files, relative_path)
            elseif type == "directory" then
                -- Recursively gather files in subdirectory
                local sub_files = list_files_in_dir(full_path, root)
                for _, sub_file in ipairs(sub_files) do
                    table.insert(files, sub_file)
                end
            end
        end
    end
    return files
end

-- Function to list all files in reusable directory and its subdirectories
local function list_files()
    return list_files_in_dir(reusable_dir, reusable_dir)
end

-- Function to prompt user to select a file to insert, conditioned by "." prefix in search
function select_file()
    local files = list_files()
    if #files == 0 then
        print("No files found in reusable directory")
        return
    end

    -- Ensure Telescope and required modules are loaded
    local ok_pickers, pickers = pcall(require, 'telescope.pickers')
    local ok_finders, finders = pcall(require, 'telescope.finders')
    local ok_actions, actions = pcall(require, 'telescope.actions')
    local ok_actions_state, actions_state = pcall(require, 'telescope.actions.state')
    local ok_sorters, sorters = pcall(require, 'telescope.sorters')
    local ok_previewers, previewers = pcall(require, 'telescope.previewers')

    if not (ok_pickers and ok_finders and ok_actions and ok_actions_state and ok_sorters and ok_previewers) then
        print("Telescope or one of its components is not available")
        return
    end

    -- Use Telescope for file selection, with conditional dotfile visibility and previewer
    pickers.new({}, {
        prompt_title = "Select Code Snippet",
        finder = finders.new_table {
            results = files,    
            entry_maker = function(entry)
                -- Check if the search input starts with a dot
                local search_input = vim.fn.getcmdline()
                local show_dotfiles = search_input:sub(1, 1) == "."
                local is_dotfile = entry:match("^%.")

                local full_path = reusable_dir .. entry
                
                -- Include the entry only if it's not a dotfile, or if dotfiles are allowed by search input
                if not is_dotfile or show_dotfiles then
                    return {
                        value = full_path,
                        display = entry,
                        ordinal = entry,
                    }
                end
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        previewer = previewers.new_termopen_previewer({
            get_command = function(entry)
                -- Return the command to show the file contents in preview
                return { "bat", "--style=plain", "--wrap=never", "--theme=GitHub", entry.value }
            end,
        }),
        attach_mappings = function(_, map)
            map('i', '<CR>', function(bufnr)
                local selection = actions_state.get_selected_entry()
                actions.close(bufnr)
                insert_file_content(selection.value)
            end)
            return true
        end
    }):find()
end

function select_file_in_subdir(sub)
    -- Set the subdirectory
    sub_dir = sub
    reusable_dir = core_dir .. sub_dir .. "/"
    print("Switched to subdirectory: " .. reusable_dir)

    -- Execute the main function
    select_file()

    -- Reset the subdirectory
    sub_dir = ""
    reusable_dir = core_dir
    print("Reset to core directory: " .. reusable_dir)
end

-- Map command to call select_file directly
vim.api.nvim_set_keymap("n", "<leader>ri", "<cmd>lua select_file()<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<leader>rs", "<cmd>lua select_file_in_subdir('swift')<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>rp", "<cmd>lua select_file_in_subdir('python')<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>rj", "<cmd>lua select_file_in_subdir('javascript')<CR>", { noremap = true, silent = true })
