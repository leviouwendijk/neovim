local path = require("core.filetype.path")
local stats = require("core.filetype.stats")

local M = {}

local keymap = "<leader>fs"

local function display_name(directory)
    local name = vim.fs.basename(directory)
    if name and name ~= "" then
        return name
    end

    return directory
end

local function selected_name(name)
    if not name then
        return nil
    end

    local normalized =
        name:gsub("/+$", "")

    if normalized == "" then
        return name
    end

    return normalized
end

local function pad(text, width)
    text = tostring(text or "")
    local missing =
        width - vim.fn.strdisplaywidth(text)

    return text .. string.rep(
        " ",
        math.max(0, missing)
    )
end

local function table_lines(headers, rows)
    local widths = {}

    for index, header in ipairs(headers) do
        widths[index] =
            vim.fn.strdisplaywidth(header)
    end

    for _, row in ipairs(rows) do
        for index, value in ipairs(row) do
            widths[index] =
                math.max(
                    widths[index] or 0,
                    vim.fn.strdisplaywidth(
                        tostring(value or "")
                    )
                )
        end
    end

    local function format_row(row)
        local parts = {}

        for index, value in ipairs(row) do
            table.insert(
                parts,
                pad(value, widths[index])
            )
        end

        return table.concat(parts, "  ")
    end

    local header = format_row(headers)
    local lines = {
        header,
        string.rep(
            "─",
            vim.fn.strdisplaywidth(header)
        ),
    }

    for _, row in ipairs(rows) do
        table.insert(
            lines,
            format_row(row)
        )
    end

    return lines
end

function M.lines(directory_model, selected)
    local lines = {
        "Directory stats",
        "",
        "Name       "
            .. display_name(
                directory_model.directory
            ),
    }

    selected = selected_name(selected)

    if selected == "." or selected == ".." then
        table.insert(
            lines,
            "Selected   " .. selected
        )
    end

    table.insert(
        lines,
        "Path       "
            .. directory_model.directory
    )
    table.insert(
        lines,
        "Files      "
            .. tostring(directory_model.files)
    )
    table.insert(
        lines,
        "Directories "
            .. tostring(
                directory_model.directories
            )
    )
    table.insert(lines, "")
    table.insert(lines, "File types")

    local type_rows = {}

    for _, item in ipairs(
        directory_model.types
    ) do
        table.insert(type_rows, {
            item.ext,
            tostring(item.count),
            string.format(
                "%.1f%%",
                item.percentage
            ),
        })
    end

    if #type_rows == 0 then
        table.insert(lines, "(none)")
    else
        vim.list_extend(
            lines,
            table_lines(
                {
                    "Type",
                    "Count",
                    "Share",
                },
                type_rows
            )
        )
    end

    table.insert(lines, "")
    table.insert(lines, "Contents")

    local content_rows = {}

    for _, entry in ipairs(
        directory_model.entries
    ) do
        table.insert(content_rows, {
            entry.name,
            entry.kind,
            entry.extension or "",
        })
    end

    if #content_rows == 0 then
        table.insert(lines, "(empty)")
    else
        vim.list_extend(
            lines,
            table_lines(
                {
                    "Name",
                    "Kind",
                    "Type",
                },
                content_rows
            )
        )
    end

    return lines
end

local function open_window(lines)
    local width = math.min(
        math.max(
            60,
            math.floor(vim.o.columns * 0.72)
        ),
        math.max(20, vim.o.columns - 4)
    )
    local height = math.min(
        #lines,
        math.max(5, vim.o.lines - 4)
    )
    local row = math.max(
        0,
        math.floor(
            (vim.o.lines - height) / 2
        ) - 1
    )
    local col = math.max(
        0,
        math.floor(
            (vim.o.columns - width) / 2
        )
    )

    local buf =
        vim.api.nvim_create_buf(
            false,
            true
        )

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        lines
    )
    vim.bo[buf].modifiable = false

    local win =
        vim.api.nvim_open_win(
            buf,
            true,
            {
                relative = "editor",
                style = "minimal",
                border = "rounded",
                title = " Directory stats ",
                title_pos = "center",
                width = width,
                height = height,
                row = row,
                col = col,
            }
        )

    vim.wo[win].wrap = false
    vim.wo[win].cursorline = true

    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(
                win,
                true
            )
        end
    end

    vim.keymap.set(
        "n",
        "q",
        close,
        {
            buffer = buf,
            silent = true,
            nowait = true,
        }
    )
    vim.keymap.set(
        "n",
        "<Esc>",
        close,
        {
            buffer = buf,
            silent = true,
            nowait = true,
        }
    )

    return buf, win
end

function M.open(directory, selected)
    local directory_model, scan_error =
        stats.scan(directory)

    if not directory_model then
        vim.notify(
            "Failed to inspect directory: "
                .. tostring(scan_error),
            vim.log.levels.ERROR
        )
        return nil
    end

    local buf, win =
        open_window(
            M.lines(
                directory_model,
                selected
            )
        )

    vim.keymap.set(
        "n",
        "r",
        function()
            local refreshed, refresh_error =
                stats.scan(directory)

            if not refreshed then
                vim.notify(
                    "Failed to refresh directory: "
                        .. tostring(refresh_error),
                    vim.log.levels.ERROR
                )
                return
            end

            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(
                buf,
                0,
                -1,
                false,
                M.lines(
                    refreshed,
                    selected
                )
            )
            vim.bo[buf].modifiable = false
        end,
        {
            buffer = buf,
            silent = true,
            desc = "Refresh directory stats",
        }
    )

    return buf, win
end

function M.open_under_cursor()
    if vim.bo.filetype ~= "netrw" then
        return nil
    end

    local entry =
        path.get_entry_under_cursor(
            vim.api.nvim_win_get_cursor(0)[1]
                - 1
        )

    if
        not entry
        or entry.type ~= "directory"
    then
        vim.notify(
            "Directory stats are available for directories",
            vim.log.levels.INFO
        )
        return nil
    end

    return M.open(
        entry.path,
        entry.name
    )
end

function M.attach(buf)
    vim.keymap.set(
        "n",
        keymap,
        M.open_under_cursor,
        {
            buffer = buf,
            silent = true,
            desc = "Inspect directory stats",
        }
    )
end

vim.api.nvim_create_autocmd(
    "FileType",
    {
        pattern = "netrw",
        callback = function(event)
            M.attach(event.buf)
        end,
    }
)

return M
