local core = require("core.confirm")

local M = {}

local namespace =
    vim.api.nvim_create_namespace(
        "interface.confirm"
    )

local function display_width(value)
    return vim.fn.strdisplaywidth(value)
end

local function max_line_width(lines)
    local width = 0

    for _, line in ipairs(lines) do
        width =
            math.max(
                width,
                display_width(line)
            )
    end

    return width
end

local function visual_rows(lines, width)
    local rows = 0
    local available = math.max(1, width)

    for _, line in ipairs(lines) do
        rows =
            rows
            + math.max(
                1,
                math.ceil(
                    display_width(line)
                    / available
                )
            )
    end

    return rows
end

function M.layout(
    prompt,
    options,
    columns,
    screen_lines
)
    options = options or {}
    columns = columns or vim.o.columns
    screen_lines =
        screen_lines or vim.o.lines

    local accept_label =
        options.accept_label or "Yes"
    local cancel_label =
        options.cancel_label or "No"

    local lines =
        vim.split(
            tostring(prompt),
            "\n",
            {
                plain = true,
            }
        )

    table.insert(lines, "")
    table.insert(
        lines,
        "y  "
            .. accept_label
            .. "    n / Esc  "
            .. cancel_label
    )

    local available_width =
        math.max(
            1,
            columns - 6
        )
    local width =
        math.min(
            options.max_width or 72,
            available_width
        )

    width =
        math.min(
            width,
            math.max(
                24,
                max_line_width(lines) + 4
            )
        )

    local inner_width =
        math.max(
            1,
            width - 4
        )
    local available_height =
        math.max(
            1,
            screen_lines - 6
        )
    local height =
        math.min(
            visual_rows(
                lines,
                inner_width
            ),
            available_height
        )

    return {
        title =
            options.title or "Confirm",
        kind =
            options.kind or "normal",
        lines = lines,
        width = width,
        height = height,
    }
end

local function border_highlight(kind)
    if kind == "danger" then
        return "DiagnosticError"
    end

    if kind == "warning" then
        return "DiagnosticWarn"
    end

    if kind == "info" then
        return "DiagnosticInfo"
    end

    return "FloatBorder"
end

local function close(buf, win)
    if
        win
        and vim.api.nvim_win_is_valid(win)
    then
        pcall(
            vim.api.nvim_win_close,
            win,
            true
        )
    end

    if
        buf
        and vim.api.nvim_buf_is_valid(buf)
    then
        pcall(
            vim.api.nvim_buf_delete,
            buf,
            {
                force = true,
            }
        )
    end
end

local function read_key()
    local value = vim.fn.getchar()

    if type(value) == "number" then
        return vim.fn.nr2char(value)
    end

    return value
end

function M.present(prompt, options)
    options = options or {}

    if #vim.api.nvim_list_uis() == 0 then
        return nil
    end

    local layout =
        M.layout(
            prompt,
            options
        )

    local buf =
        vim.api.nvim_create_buf(
            false,
            true
        )

    vim.api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        layout.lines
    )

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "confirm"

    local row =
        math.max(
            0,
            math.floor(
                (vim.o.lines - layout.height)
                / 2
            ) - 1
        )
    local col =
        math.max(
            0,
            math.floor(
                (vim.o.columns - layout.width)
                / 2
            )
        )

    local opened, win =
        pcall(
            vim.api.nvim_open_win,
            buf,
            true,
            {
                relative = "editor",
                row = row,
                col = col,
                width = layout.width,
                height = layout.height,
                style = "minimal",
                border = "rounded",
                title =
                    " "
                    .. layout.title
                    .. " ",
                title_pos = "center",
                zindex = 250,
            }
        )

    if not opened then
        close(buf, nil)
        return nil
    end

    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    vim.wo[win].breakindent = true
    vim.wo[win].cursorline = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].winhl =
        "Normal:NormalFloat,FloatBorder:"
        .. border_highlight(
            layout.kind
        )

    local hint_line =
        #layout.lines - 1

    if hint_line >= 0 then
        local hint_text =
            layout.lines[
                hint_line + 1
            ] or ""

        vim.api.nvim_buf_set_extmark(
            buf,
            namespace,
            hint_line,
            0,
            {
                end_row = hint_line,
                end_col = #hint_text,
                hl_group = "Comment",
            }
        )
    end

    vim.cmd("redraw")

    local ok, result =
        pcall(
            function()
                while true do
                    local key = read_key()

                    if
                        key == "y"
                        or key == "Y"
                    then
                        return true
                    end

                    if
                        key == "n"
                        or key == "N"
                        or key == "q"
                        or key == "\027"
                        or key == "\003"
                    then
                        return false
                    end

                    if
                        key == "\r"
                        or key == "\n"
                    then
                        return options.default == true
                    end
                end
            end
        )

    close(buf, win)

    if not ok then
        return nil
    end

    return result
end

core.set_presenter(M.present)

return M
