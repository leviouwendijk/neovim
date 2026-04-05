-- Ensure Telescope is loaded
local ok, telescope = pcall(require, "telescope")
if not ok then
    print("Telescope is not installed or loaded")
    return
end

-- Dependencies
local Path = require("plenary.path")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")

-- Function to refresh Netrw
local function refresh_netrw(cwd)
    -- Change to the current directory
    vim.cmd("lcd " .. cwd)
    -- Reload the Netrw buffer
    vim.cmd("Rex")
end

-- Rename File Function
function RenameFile(cwd)
    local files = vim.fn.readdir(cwd)
    pickers.new({}, {
        prompt_title = "Rename File",
        finder = finders.new_table { results = files },
        sorter = sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = actions_state.get_selected_entry()
                actions.close(prompt_bufnr)

                vim.ui.input({ prompt = "New name for " .. selection.value .. ": " }, function(input)
                    if input and input ~= "" then
                        local old_path = Path:new(cwd, selection.value):absolute()
                        local new_path = Path:new(cwd, input):absolute()
                        local success, err = os.rename(old_path, new_path)
                        if success then
                            print("Renamed " .. selection.value .. " to " .. input)
                            -- Refresh Netrw to reflect changes
                            refresh_netrw(cwd)
                        else
                            print("Error renaming file: " .. err)
                        end
                    end
                end)
            end)
            return true
        end,
    }):find()
end

-- Rename File Under Cursor in Netrw
function RenameCursorFile()
    local cwd = vim.fn.getcwd()
    local cursor_line = vim.fn.line(".")
    local file_name = vim.fn.getline(cursor_line):match("^%s*(.-)%s*$")
    if not file_name or file_name == "" then
        print("No valid file under cursor")
        return
    end

    local old_path = Path:new(cwd, file_name):absolute()

    -- Close the buffer associated with the old file, if any
    local old_buf = vim.fn.bufnr(old_path)
    if old_buf > 0 and vim.api.nvim_buf_is_loaded(old_buf) then
        -- Temporarily disable buffer events to prevent unintended actions
        vim.cmd("set eventignore=BufWritePre,BufFilePost,BufReadPost")
        vim.cmd("bdelete! " .. old_buf)
        vim.cmd("set eventignore=") -- Re-enable events
    end

    vim.ui.input({ prompt = "New name for " .. file_name .. ": " }, function(input)
        if input and input ~= "" then
            vim.cmd("redraw")
            local new_path = Path:new(cwd, input):absolute()
            local success, err = os.rename(old_path, new_path)
            if success then
                print("Renamed " .. file_name .. " to " .. input)
                refresh_netrw(cwd)

                -- Restore cursor to the renamed file
                local lines = vim.fn.getline(1, "$") -- Get all buffer lines as a list
                if type(lines) == "table" then
                    for lnum, line in ipairs(lines) do
                        if line:find(input, 1, true) then
                            vim.fn.cursor(lnum, 0)
                            break
                        end
                    end
                else
                    print("Warning: Unable to process Netrw lines")
                end
            else
                print("Error renaming file: " .. err)
            end
        end
    end)
end

-- Key Mappings
vim.api.nvim_set_keymap("n", "<leader>rn", ":lua RenameFile(vim.loop.cwd())<CR>", { noremap = true, silent = true }) -- Rename with Telescope
vim.api.nvim_set_keymap("n", "<leader>rr", ":lua RenameCursorFile()<CR>", { noremap = true, silent = true }) -- Rename under cursor
