local core = require("extensions.file_rename.core")

local M = {}

local function normalize_entry(name)
    if type(name) ~= "string" then
        return nil
    end

    name = name:gsub("/+$", "")

    if name == ""
        or name == "."
        or name == ".."
    then
        return nil
    end

    return name
end

function M.active_directory()
    if vim.bo.filetype == "netrw"
        and vim.b.netrw_curdir
        and vim.b.netrw_curdir ~= ""
    then
        return core.normalize_path(
            vim.b.netrw_curdir
        )
    end

    local name = vim.api.nvim_buf_get_name(0)

    if name ~= ""
        and vim.fn.isdirectory(name) == 1
    then
        return core.normalize_path(name)
    end

    return core.normalize_path(
        vim.fn.getcwd()
    )
end

function M.entry_under_cursor()
    if vim.bo.filetype ~= "netrw" then
        return nil
    end

    local ok, entry = pcall(
        vim.fn["netrw#Call"],
        "NetrwGetWord"
    )

    if not ok then
        return nil
    end

    return normalize_entry(entry)
end

function M.refresh(directory, target_name)
    local win = vim.api.nvim_get_current_win()
    local previous_cursor =
    vim.api.nvim_win_get_cursor(win)

    vim.cmd(
        "silent keepalt keepjumps edit "
        .. vim.fn.fnameescape(directory)
    )

    if vim.bo.filetype ~= "netrw"
        or not target_name
    then
        return false
    end

    local line_count =
    vim.api.nvim_buf_line_count(0)

    for row = 1, line_count do
        vim.api.nvim_win_set_cursor(
            win,
            { row, 0 }
        )

        if M.entry_under_cursor() == target_name then
            return true
        end
    end

    pcall(
        vim.api.nvim_win_set_cursor,
        win,
        previous_cursor
    )

    return false
end

return M
