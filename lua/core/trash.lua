-- local function sanitize_path(path)
--     return path:gsub('//+', '/')
-- end

-- local Popup = require("plenary.popup")

local acc = require("accessor")
local funcs = require("config.funcs")

local YES_LINE = 4
local NO_LINE = 5
local PICKER_NS = vim.api.nvim_create_namespace("core.trash")

local function plenaryPicker(prompt_title, callback, current_line)
    local width = 50
    local height = 6

    -- Create the popup
    local win_buf = vim.api.nvim_create_buf(false, true)
    if not win_buf then
        print("Error creating buffer for popup")
        return
    end

    local win_id = vim.api.nvim_open_win(win_buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2),
        border = "single",
    })

    -- Set the buffer content
    vim.api.nvim_buf_set_lines(win_buf, 0, -1, false, {
        "",
        prompt_title,
        "",
        "  Yes",
        "  No",
        ""
    }
    )

    vim.bo[win_buf].buftype = "prompt" -- Disable editing, ideal for a selection popup
    vim.bo[win_buf].modifiable = false
    vim.bo[win_buf].bufhidden = "wipe"
    -- Disable line numbers for the popup
    vim.wo[win_id].number = false
    vim.wo[win_id].relativenumber = false

    -- Create a custom highlight group for the bold filename
    vim.api.nvim_set_hl(0, "PickerBold", { bold = true })

    -- Apply the highlight to the filename line
    -- vim.api.nvim_buf_add_highlight(win_buf, -1, "PickerBold", 1, 0, -1)
    vim.api.nvim_buf_set_extmark(win_buf, PICKER_NS, 1, 0, {
        end_row = 1,
        end_col = #prompt_title,
        hl_group = "PickerBold",
    })

    -- Set the default cursor position to the "Yes" line
    vim.api.nvim_win_set_cursor(win_id, { YES_LINE, 0 })

    local function close_picker(restore_cursor)
        if vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, true)
        end
        if restore_cursor then
            restore_cursor()
        end
    end

    -- Handle user input
    vim.api.nvim_buf_set_keymap(win_buf, "n", "k", "", {
        noremap = true,
        silent = true,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win_id)
            vim.api.nvim_win_set_cursor(win_id, { math.max(cursor[1] - 1, YES_LINE), cursor[2] })
        end,
    })

    vim.api.nvim_buf_set_keymap(win_buf, "n", "j", "", {
        noremap = true,
        silent = true,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win_id)
            vim.api.nvim_win_set_cursor(win_id, { math.min(cursor[1] + 1, NO_LINE), cursor[2] })
        end,
    })

    vim.api.nvim_buf_set_keymap(win_buf, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = function()
            local cursor = vim.api.nvim_win_get_cursor(win_id)
            local choice = (cursor[1] == YES_LINE) and "Yes" or "No"
            close_picker()
            callback(choice)
        end,
    })

    vim.api.nvim_buf_set_keymap(win_buf, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
            close_picker(function()
                vim.fn.cursor(current_line, 0)
            end)
        end,
    })

    vim.api.nvim_buf_set_keymap(win_buf, "n", "<C-c>", "", {
        noremap = true,
        silent = true,
        callback = function()
            close_picker(function()
                vim.fn.cursor(current_line, 0)
            end)
        end,
    })

    -- Add 'y' and 'n' mappings for Yes and No
    vim.api.nvim_buf_set_keymap(win_buf, "n", "y", "", {
        noremap = true,
        silent = true,
        callback = function()
            close_picker()
            callback("Yes") -- Pass "Yes" to the callback when 'y' is pressed
        end,
    })

    vim.api.nvim_buf_set_keymap(win_buf, "n", "n", "", {
        noremap = true,
        silent = true,
        callback = function()
            close_picker(function()
                vim.fn.cursor(current_line, 0)
            end)
        end,
    })
end

-- util: optionally auto-press <CR> to kill any pending "Press ENTER"
local function press_enter()
  local cr = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  vim.api.nvim_feedkeys(cr, "n", false)
end

local function safe_notify(msg, level)
  -- avoids hit-enter; levels: :help vim.log.levels
  vim.notify(msg, level or vim.log.levels.INFO)
end

function NetrwTrash(absolute_path)
    -- Save the current cursor position
    local current_cursor = vim.fn.getcurpos()
    local current_line = current_cursor[2]

    -- Get the absolute filepath of the file under the cursor
    local filepath = vim.fn.fnamemodify(vim.fn.expand("%:p") .. vim.fn.getline('.'), ":p")
    if not filepath or filepath == "" then
        print("No file selected!")
        return
    end

    -- Determine the appearance of the path in the picker
    local display_path = absolute_path and filepath or vim.fn.fnamemodify(vim.fn.expand("%:p") .. vim.fn.getline('.'), ":p")

    -- local trash_cmd = "trash " .. vim.fn.shellescape(filepath)
    local trash_cmd = { acc.bin.trash, filepath }

    -- exit if unavailable
    local ok_trash = funcs.has_executable(acc.bin.trash)
    if not ok_trash then
        safe_notify("Trash helper is unavailable", vim.log.levels.WARN)
        return
    end

    local function perform_trash(action)
        if action == "Yes" then
            -- vim.fn.jobstart(trash_cmd, {
            --     detach = true,
            --     on_exit = function()
            --         vim.cmd("edit") -- Refresh the buffer
            --         local success = pcall(function()
            --             vim.fn.cursor(current_line, 0) -- Attempt to move back to the original line
            --         end)
            --         if not success then
            --             vim.fn.cursor(vim.fn.line('$'), 0) -- Fallback to the last line if it fails
            --         end
            --         -- print(filepath .. " moved to Trash.")
            --         safe_notify(filepath .. " moved to Trash.")
            --         press_enter()
            --     end,
            -- })
            local job = funcs.jobstart(trash_cmd, {
                detach = true,
                on_exit = function()
                    vim.cmd("edit") -- Refresh the buffer
                    local success = pcall(function()
                        vim.fn.cursor(current_line, 0) -- Attempt to move back to the original line
                    end)
                    if not success then
                        vim.fn.cursor(vim.fn.line('$'), 0) -- Fallback to the last line if it fails
                    end
                    safe_notify(filepath .. " moved to Trash.")
                    press_enter()
                end,
            })

            if job <= 0 then
                safe_notify("Failed to launch trash helper", vim.log.levels.ERROR)
            end
        else
            -- Restore the cursor if the action is cancelled
            vim.fn.cursor(current_line, 0)
            -- print("Cancelled trash operation.")
            safe_notify("Cancelled trash operation.", vim.log.levels.WARN)
            press_enter()
        end
    end

    -- Open the picker
    plenaryPicker("Trash " .. display_path .. "?", perform_trash, current_line)
end

-- function for seeing if we can somehow detect files in other directories than where we entered as cwd
function TestAbsoluteFilepath()
    print("Testing various methods to get the absolute filepath:")

    -- Method 1: Use <cfile>
    local cfile_path = vim.fn.expand("<cfile>:p")
    print("Method 1 (expand '<cfile>:p'):", cfile_path)

    -- Method 2: Use expand with '%'
    local percent_path = vim.fn.expand("%:p")
    print("Method 2 (expand '%:p'):", percent_path)

    -- Method 3: Directly use netrw API (if available)
    local filepath_netrw = vim.fn.fnamemodify(vim.fn.expand("%:p") .. vim.fn.getline('.'), ":p")
    print("Method 3 (custom netrw expansion):", filepath_netrw)

    -- Method 4: Combine current directory and filename
    local current_dir = vim.fn.getcwd()
    local relative_path = vim.fn.expand("<cfile>")
    local combined_path = vim.fn.fnamemodify(current_dir .. "/" .. relative_path, ":p")
    print("Method 4 (current directory + relative path):", combined_path)
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'netrw',
    callback = function()
        vim.api.nvim_buf_set_keymap(0, 'n', 'D', ':lua NetrwTrash()<CR>', { noremap = true, silent = true })
    end,
})
