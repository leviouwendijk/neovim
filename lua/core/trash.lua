-- local function sanitize_path(path)
--     return path:gsub('//+', '/')
-- end

-- local Popup = require("plenary.popup")

local acc = require("accessor")
local funcs = require("config.funcs")

local YES_LINE = 4
local NO_LINE = 5
local PICKER_NS = vim.api.nvim_create_namespace("core.trash")

local function trashPicker(prompt_title, callback, current_line)
    local hint =
        "j/k move  ·  Enter select  ·  Esc cancel"

    local available_width =
        math.max(
            1,
            vim.o.columns - 4
        )
    local width =
        math.min(
            available_width,
            math.max(
                42,
                math.min(
                    72,
                    math.max(
                        vim.fn.strdisplaywidth(prompt_title),
                        vim.fn.strdisplaywidth(hint)
                    ) + 4
                )
            )
        )
    local height =
        math.min(
            7,
            math.max(
                1,
                vim.o.lines - 4
            )
        )

    -- Create the popup.
    local win_buf =
        vim.api.nvim_create_buf(
            false,
            true
        )

    if not win_buf then
        print("Error creating buffer for popup")
        return
    end

    vim.b[win_buf].indentation_overlay_disabled = true

    local opened, win_id =
        pcall(
            vim.api.nvim_open_win,
            win_buf,
            true,
            {
                relative = "editor",
                width = width,
                height = height,
                col =
                    math.max(
                        0,
                        math.floor(
                            (vim.o.columns - width)
                            / 2
                        )
                    ),
                row =
                    math.max(
                        0,
                        math.floor(
                            (vim.o.lines - height)
                            / 2
                        ) - 1
                    ),
                border = "rounded",
                title = " Trash ",
                title_pos = "center",
                style = "minimal",
                zindex = 250,
            }
        )

    if not opened then
        pcall(
            vim.api.nvim_buf_delete,
            win_buf,
            {
                force = true,
            }
        )
        funcs.safe_notify(
            "Unable to open trash confirmation",
            vim.log.levels.ERROR
        )
        return
    end

    -- This picker is a fixed selection surface. Keep nvim-cmp available
    -- globally, but suppress its ghost text specifically in this buffer.
    local ok_cmp, cmp = pcall(require, "cmp")
    if ok_cmp and cmp.setup and cmp.setup.buffer then
        cmp.setup.buffer({
            experimental = {
                ghost_text = false,
            },
        })
    end

    -- Selection is deliberately movement + Enter only. The destructive
    -- choice is not the default and has no single-key shortcut.
    vim.api.nvim_buf_set_lines(
        win_buf,
        0,
        -1,
        false,
        {
            "",
            prompt_title,
            "",
            "  Move to Trash",
            "  Cancel",
            "",
            hint,
        }
    )

    vim.bo[win_buf].buftype = "nofile"
    vim.bo[win_buf].modifiable = false
    vim.bo[win_buf].bufhidden = "wipe"
    vim.bo[win_buf].swapfile = false
    vim.bo[win_buf].filetype = "trash-confirm"

    vim.wo[win_id].number = false
    vim.wo[win_id].relativenumber = false
    vim.wo[win_id].signcolumn = "no"
    vim.wo[win_id].cursorline = true
    vim.wo[win_id].winhl =
        "Normal:NormalFloat,"
        .. "FloatBorder:DiagnosticWarn,"
        .. "CursorLine:Visual"

    vim.api.nvim_buf_set_extmark(
        win_buf,
        PICKER_NS,
        1,
        0,
        {
            end_row = 1,
            end_col = #prompt_title,
            hl_group = "Title",
        }
    )

    vim.api.nvim_buf_set_extmark(
        win_buf,
        PICKER_NS,
        6,
        0,
        {
            end_row = 6,
            end_col = #hint,
            hl_group = "Comment",
        }
    )

    -- Start on Cancel so confirming always requires an intentional move
    -- followed by Enter.
    vim.api.nvim_win_set_cursor(
        win_id,
        {
            NO_LINE,
            0,
        }
    )

    local function close_picker(restore_cursor)
        if vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(
                win_id,
                true
            )
        end

        if restore_cursor then
            restore_cursor()
        end
    end

    local function move_choice(delta)
        if not vim.api.nvim_win_is_valid(win_id) then
            return
        end

        local cursor =
            vim.api.nvim_win_get_cursor(
                win_id
            )
        local line =
            math.max(
                YES_LINE,
                math.min(
                    NO_LINE,
                    cursor[1] + delta
                )
            )

        vim.api.nvim_win_set_cursor(
            win_id,
            {
                line,
                0,
            }
        )
    end

    local function map(lhs, callback_fn)
        vim.keymap.set(
            "n",
            lhs,
            callback_fn,
            {
                buffer = win_buf,
                noremap = true,
                silent = true,
                nowait = true,
            }
        )
    end

    map("k", function()
        move_choice(-1)
    end)

    map("<Up>", function()
        move_choice(-1)
    end)

    map("j", function()
        move_choice(1)
    end)

    map("<Down>", function()
        move_choice(1)
    end)

    map("<CR>", function()
        local cursor =
            vim.api.nvim_win_get_cursor(
                win_id
            )
        local choice =
            cursor[1] == YES_LINE
            and "Yes"
            or "No"

        close_picker()
        callback(choice)
    end)

    local function cancel()
        close_picker(function()
            vim.fn.cursor(
                current_line,
                0
            )
        end)
    end

    map("q", cancel)
    map("<Esc>", cancel)
    map("<C-c>", cancel)
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
    trashPicker(
        "Trash " .. display_path .. "?",
        perform_trash,
        current_line
    )
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
