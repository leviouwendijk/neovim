local core = require("extensions.filemover.core")

local M = {}

function M.active_directory()
    if vim.bo.filetype == "netrw"
        and vim.b.netrw_curdir
        and vim.b.netrw_curdir ~= ""
    then
        return core.normalize_path(vim.b.netrw_curdir)
    end

    local name = vim.api.nvim_buf_get_name(0)
    if name ~= "" and vim.fn.isdirectory(name) == 1 then
        return core.normalize_path(name)
    end

    return core.normalize_path(vim.fn.getcwd())
end

function M.marked_paths()
    local ok, marked = pcall(
        vim.fn["netrw#Expose"],
        "netrwmarkfilelist"
    )

    if not ok then
        return nil, tostring(marked)
    end

    if type(marked) ~= "table" then
        return {}, nil
    end

    return marked, nil
end

function M.clear_marks()
    if vim.bo.filetype ~= "netrw" then
        return
    end

    local keys = vim.api.nvim_replace_termcodes(
        "mu",
        true,
        false,
        true
    )

    vim.api.nvim_feedkeys(keys, "mx", false)
end

function M.refresh(ctx)
    if ctx.win and vim.api.nvim_win_is_valid(ctx.win) then
        vim.api.nvim_set_current_win(ctx.win)
    end

    if ctx.dir and (vim.uv or vim.loop).fs_stat(ctx.dir) then
        vim.cmd(
            "silent keepalt keepjumps edit "
            .. vim.fn.fnameescape(ctx.dir)
        )
    end

    if ctx.cursor then
        pcall(vim.api.nvim_win_set_cursor, 0, ctx.cursor)
    end
end

return M
