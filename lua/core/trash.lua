-- local function sanitize_path(path)
--     return path:gsub('//+', '/')
-- end

-- local Popup = require("plenary.popup")

local acc = require("accessor")
local funcs = require("config.funcs")
local path = require("config.path")
local netrw_selection = require("core.netrw-selection")
local filemover_core = require("extensions.filemover.core")

local M = {}

local function trash_roots()
    local roots = {}

    if path.home ~= "" then
        table.insert(
            roots,
            path.home_join(".Trash")
        )
    end

    local xdg_data_home =
        vim.env.XDG_DATA_HOME

    if
        not xdg_data_home
        or xdg_data_home == ""
    then
        xdg_data_home =
            path.home_join(
                ".local",
                "share"
            )
    end

    if xdg_data_home ~= "" then
        table.insert(
            roots,
            path.join(
                xdg_data_home,
                "Trash",
                "files"
            )
        )
    end

    return roots
end

function M.is_in_trash(filepath)
    local normalized =
        path.normalize(filepath)

    if normalized == "" then
        return false
    end

    for _, root in ipairs(trash_roots()) do
        local normalized_root =
            path.normalize(root)

        -- The trash root itself is not considered an item inside Trash.
        if
            normalized ~= normalized_root
            and path.is_relative_to(
                normalized,
                normalized_root
            )
        then
            return true
        end
    end

    return false
end

function M.permanent_delete(filepath)
    local stat, stat_error =
        vim.uv.fs_lstat(filepath)

    if not stat then
        return false,
            stat_error
                or "path does not exist"
    end

    -- lstat is intentional: a symlink to a directory must be unlinked as
    -- an entry, never followed recursively into its target.
    if stat.type == "directory" then
        local result =
            vim.fn.delete(
                filepath,
                "rf"
            )

        if result ~= 0 then
            return false,
                "failed to remove directory tree"
        end

        return true
    end

    local unlinked, unlink_error =
        vim.uv.fs_unlink(filepath)

    if not unlinked then
        return false,
            unlink_error
                or "failed to unlink path"
    end

    return true
end

local YES_LINE = 4
local NO_LINE = 5
local PICKER_NS = vim.api.nvim_create_namespace("core.trash")

local function trashPicker(
    prompt_title,
    callback,
    current_line,
    options
)
    options = options or {}

    local hint =
        "j/k move  ·  Enter select  ·  Esc cancel"
    local action_label =
        options.action_label
        or "Move to Trash"
    local cancel_label =
        options.cancel_label
        or "Cancel"
    local title =
        options.title
        or "Trash"
    local border_highlight =
        options.kind == "danger"
        and "DiagnosticError"
        or "DiagnosticWarn"

    local action_line =
        "  " .. action_label
    local cancel_line =
        "  " .. cancel_label

    local picker_lines = {
        "", prompt_title, "", action_line, cancel_line, "", hint,
    }
    if options.preview_paths and #options.preview_paths > 0 then
        picker_lines[#picker_lines + 1] = ""
        picker_lines[#picker_lines + 1] =
            ("Selected entries (%d):"):format(#options.preview_paths)
        for _, item in ipairs(options.preview_paths) do
            picker_lines[#picker_lines + 1] =
                "  " .. vim.fn.fnamemodify(item, ":~:.")
        end
    end

    -- Size against the actual rendered content, including batch paths.
    -- Never rely on implicit wrapping: height is measured in buffer lines.
    local longest_line = vim.fn.strdisplaywidth(title)
    for _, line in ipairs(picker_lines) do
        longest_line = math.max(
            longest_line,
            vim.fn.strdisplaywidth(line)
        )
    end
    local available_width = math.max(1, vim.o.columns - 4)
    local width = math.min(
        available_width,
        math.max(42, math.min(96, longest_line + 2))
    )
    local height =
        math.min(
            #picker_lines,
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
                title =
                    " "
                    .. title
                    .. " ",
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
        picker_lines
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
    -- Long paths pan horizontally (zh/zl) instead of consuming extra rows.
    vim.wo[win_id].wrap = false
    vim.wo[win_id].winhl =
        "Normal:NormalFloat,"
        .. "FloatBorder:"
        .. border_highlight
        .. ",CursorLine:Visual"

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
        local current = cursor[1]
        local last = #picker_lines > 7 and #picker_lines or NO_LINE
        local line
        if current == NO_LINE and delta > 0 and last > NO_LINE then
            line = 9 -- skip spacer and hint
        elseif current == 9 and delta < 0 then
            line = NO_LINE
        else
            line = math.max(YES_LINE, math.min(last, current + delta))
        end

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

local function safe_notify(message, level)
    funcs.safe_notify(message, level or vim.log.levels.INFO)
end

-- Cursor, marked and visual selections all flow through the same picker.
-- Preserve the existing direct invocation used by non-netrw callers.
function NetrwTrash(absolute_path, options)
    options = options or {}
    local source_window = vim.api.nvim_get_current_win()
    local source_cursor = vim.api.nvim_win_get_cursor(source_window)
    local current_line = source_cursor[1]
    local is_netrw = vim.bo.filetype == "netrw"
    local paths, selection_kind, selection_error

    if is_netrw then
        paths, selection_kind, selection_error =
            netrw_selection.resolve(options)
    else
        paths = { vim.fn.fnamemodify(
            vim.fn.expand("%:p") .. vim.fn.getline("."), ":p"
        ) }
        selection_kind = "cursor"
    end

    if not paths then
        safe_notify("Failed to resolve netrw selection: "
            .. tostring(selection_error), vim.log.levels.ERROR)
        return
    end
    local entries = filemover_core.compact_sources(paths)
    if #entries == 0 then
        safe_notify("No files selected", vim.log.levels.WARN)
        return
    end
    paths = vim.tbl_map(function(item) return item.path end, entries)
    local ctx = is_netrw and netrw_selection.capture(paths) or nil

    local function restore_cursor()
        if vim.api.nvim_win_is_valid(source_window) then
            vim.api.nvim_set_current_win(source_window)
            pcall(vim.api.nvim_win_set_cursor, source_window, source_cursor)
        end
    end
    local function refresh()
        if ctx then
            netrw_selection.refresh(ctx)
        else
            pcall(function() vim.cmd("edit") end)
            restore_cursor()
        end
    end
    local function clear_completed_marks()
        if selection_kind == "marks" and is_netrw then
            netrw_selection.clear_marks()
        end
    end

    local in_trash = M.is_in_trash(paths[1])
    for index = 2, #paths do
        if M.is_in_trash(paths[index]) ~= in_trash then
            safe_notify(
                "Cannot mix Trash contents and ordinary files in one operation",
                vim.log.levels.ERROR
            )
            return
        end
    end

    local display = #paths == 1 and (absolute_path and paths[1]
        or vim.fn.fnamemodify(paths[1], ":~:."))
        or ("%d selected entries"):format(#paths)
    local preview = #paths > 1 and paths or nil

    if in_trash then
        local function perform_permanent_delete(action)
            if action ~= "Yes" then
                restore_cursor()
                return
            end
            local deleted, failed = 0, {}
            for _, item in ipairs(paths) do
                local success, err = M.permanent_delete(item)
                if success then
                    deleted = deleted + 1
                else
                    failed[#failed + 1] = item .. ": " .. tostring(err)
                end
            end
            if deleted > 0 then
                clear_completed_marks()
                refresh()
            end
            if #failed > 0 then
                safe_notify(("Permanently deleted %d/%d; failed:\n%s")
                    :format(deleted, #paths, table.concat(failed, "\n")),
                    vim.log.levels.ERROR)
            else
                safe_notify(("%d entries permanently deleted."):format(deleted))
            end
        end
        local function request_final_confirmation(action)
            if action ~= "Yes" then
                restore_cursor()
                return
            end
            trashPicker(
                "This cannot be undone. Permanently delete " .. display .. "?",
                perform_permanent_delete, current_line, {
                    title = "Final confirmation",
                    action_label = "Delete permanently",
                    kind = "danger", preview_paths = preview,
                }
            )
        end
        trashPicker("Permanently delete " .. display .. "?",
            request_final_confirmation, current_line, {
                title = "Permanent delete",
                action_label = "Permanently delete",
                kind = "danger", preview_paths = preview,
            })
        return
    end

    if not funcs.has_executable(acc.bin.trash) then
        safe_notify("Trash helper is unavailable", vim.log.levels.ERROR)
        return
    end

    trashPicker("Trash " .. display .. "?", function(action)
        if action ~= "Yes" then
            restore_cursor()
            return
        end
        local cmd = { acc.bin.trash }
        vim.list_extend(cmd, paths)
        local ok, err = pcall(vim.system, cmd, { text = true }, function(result)
            vim.schedule(function()
                if result.code == 0 then
                    clear_completed_marks()
                    refresh()
                    safe_notify(("%d entries moved to Trash."):format(#paths))
                else
                    -- A failed batch may have moved some entries already.
                    refresh()
                    safe_notify("Trash failed (exit " .. tostring(result.code)
                        .. "): " .. (result.stderr or ""), vim.log.levels.ERROR)
                end
            end)
        end)
        if not ok then
            safe_notify("Unable to launch trash helper: " .. tostring(err),
                vim.log.levels.ERROR)
        end
    end, current_line, {
        title = "Trash", preview_paths = preview,
    })
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
        vim.keymap.set("n", "D", function() NetrwTrash() end, {
            buffer = true, silent = true, desc = "Trash current or marked entries",
        })
        vim.keymap.set("x", "D", function()
            NetrwTrash(false, {
                visual_rows = { vim.fn.getpos("v")[2], vim.fn.line(".") },
            })
        end, {
            buffer = true, silent = true, desc = "Trash visually selected entries",
        })
    end,
})

return M
