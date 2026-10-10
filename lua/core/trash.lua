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

local trash_picker = require("interface.trash")

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
    local preview = paths

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
            trash_picker.open(
                "This cannot be undone. Permanently delete " .. display .. "?",
                perform_permanent_delete, current_line, {
                    title = "Final confirmation",
                    action_label = "Delete permanently",
                    kind = "danger", preview_paths = preview,
                }
            )
        end
        trash_picker.open("Permanently delete " .. display .. "?",
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

    trash_picker.open("Trash " .. display .. "?", function(action)
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
