-- UI-only confirmation presenter for netrw Trash operations.
-- The action rows are fixed; the selected-file preview is paged in-place.
local M = {}

local YES_LINE = 4
local NO_LINE = 5
local PICKER_NS = vim.api.nvim_create_namespace("interface.trash")

local function entries_for(paths)
    local entries = {}
    if not paths or #paths == 0 then
        return entries
    end

    -- netrw commonly selects siblings; show filenames instead of repeating
    -- a long parent path for each entry. Other selections keep relative paths.
    local parent = vim.fs.dirname(paths[1])
    local siblings = true
    for i = 2, #paths do
        if vim.fs.dirname(paths[i]) ~= parent then
            siblings = false
            break
        end
    end

    for _, file in ipairs(paths) do
        local stat = vim.uv.fs_lstat(file)
        local kind = stat and stat.type or "file"
        local prefix = kind == "directory" and "[D] "
            or kind == "link" and "[L] "
            or "[F] "
        local name = siblings and vim.fs.basename(file)
            or vim.fn.fnamemodify(file, ":~:.")
        if kind == "directory" then
            name = name:gsub("/+$", "") .. "/"
        end
        entries[#entries + 1] = "  " .. prefix .. name
    end
    return entries
end

---Compute a bounded layout without changing any Neovim windows.
---@param prompt string
---@param options table
---@param columns? integer
---@param screen_lines? integer
---@param requested_offset? integer
---@return table
function M.layout(prompt, options, columns, screen_lines, requested_offset)
    options = options or {}
    columns = columns or vim.o.columns
    screen_lines = screen_lines or vim.o.lines

    local title = options.title or "Trash"
    local action = options.action_label or "Move to Trash"
    local cancel = options.cancel_label or "Cancel"
    local entries = entries_for(options.preview_paths)
    local hint = "j/k choose  ·  Enter select  ·  Esc cancel"
    local max_height = math.max(1, screen_lines - 4)
    local page_size = #entries > 0 and math.max(0, max_height - 9) or 0
    local visible = math.min(#entries, page_size)
    local max_offset = math.max(0, #entries - visible)
    local offset = math.max(0, math.min(requested_offset or 0, max_offset))

    local lines = {
        "", tostring(prompt), "", "  " .. action, "  " .. cancel, "", hint,
    }

    if visible > 0 then
        local first = offset + 1
        local last = offset + visible
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("Selected entries (%d)  ·  %d-%d of %d  ·  ^D/^U scroll")
            :format(#entries, first, last, #entries)
        for i = offset + 1, offset + visible do
            lines[#lines + 1] = entries[i]
        end
    elseif #entries > 0 then
        -- Terminal too short for a preview: keep the action rows visible.
        lines[7] = ("%d selected entries  ·  enlarge window for preview")
            :format(#entries)
    end

    local longest = vim.fn.strdisplaywidth(title)
    for _, line in ipairs(lines) do
        longest = math.max(longest, vim.fn.strdisplaywidth(line))
    end
    -- Include the full preview in the width measurement even when only the
    -- first page is visible. Height is independent of filename wrapping.
    for _, line in ipairs(entries) do
        longest = math.max(longest, vim.fn.strdisplaywidth(line))
    end
    local width = math.min(
        math.max(1, columns - 4),
        math.max(42, math.min(96, longest + 2))
    )
    local height = math.min(#lines, max_height)
    return {
        lines = lines,
        width = width,
        height = height,
        page_size = visible,
        offset = offset,
        total = #entries,
        row = math.max(0, math.floor((screen_lines - height) / 2) - 1),
        col = math.max(0, math.floor((columns - width) / 2)),
    }
end

local function highlight(buf, lines)
    vim.api.nvim_buf_clear_namespace(buf, PICKER_NS, 0, -1)
    for _, row in ipairs({ 2, 7, 9 }) do
        local text = lines[row]
        if text and text ~= "" then
            vim.api.nvim_buf_set_extmark(buf, PICKER_NS, row - 1, 0, {
                end_row = row - 1,
                end_col = #text,
                hl_group = row == 2 and "Title" or "Comment",
            })
        end
    end
end

---Open an interactive confirmation. callback receives "Yes" or "No".
---Escape/quit closes without invoking callback, matching the old picker.
function M.open(prompt, callback, current_line, options)
    options = options or {}
    local title = options.title or "Trash"
    local border_hl = options.kind == "danger" and "DiagnosticError"
        or "DiagnosticWarn"
    local offset = 0
    local layout = M.layout(prompt, options, nil, nil, offset)
    local buf = vim.api.nvim_create_buf(false, true)
    if not buf then
        return false
    end
    vim.b[buf].indentation_overlay_disabled = true

    local opened, win = pcall(vim.api.nvim_open_win, buf, true, {
        relative = "editor",
        width = layout.width,
        height = layout.height,
        col = layout.col,
        row = layout.row,
        border = "rounded",
        title = " " .. title .. " ",
        title_pos = "center",
        style = "minimal",
        zindex = 250,
    })
    if not opened then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        vim.notify("Unable to open trash confirmation", vim.log.levels.ERROR)
        return false
    end

    -- Preserve the existing per-buffer completion/indentation suppression.
    local ok_cmp, cmp = pcall(require, "cmp")
    if ok_cmp and cmp.setup and cmp.setup.buffer then
        cmp.setup.buffer({ experimental = { ghost_text = false } })
    end

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "trash-confirm"
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].cursorline = true
    vim.wo[win].wrap = false
    vim.wo[win].winhl = "Normal:NormalFloat,FloatBorder:"
        .. border_hl .. ",CursorLine:Visual"

    local function write_lines(new_lines)
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.bo[buf].modifiable = false
        highlight(buf, new_lines)
    end
    write_lines(layout.lines)
    -- Confirming requires moving from Cancel to the destructive option.
    vim.api.nvim_win_set_cursor(win, { NO_LINE, 0 })

    local resize_id
    local closed_id
    local function remove_hooks()
        if resize_id then
            pcall(vim.api.nvim_del_autocmd, resize_id)
            resize_id = nil
        end
        if closed_id then
            pcall(vim.api.nvim_del_autocmd, closed_id)
            closed_id = nil
        end
    end
    local function close(restore)
        remove_hooks()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        if restore then
            pcall(vim.fn.cursor, current_line, 0)
        end
    end

    local function redraw(resize)
        if not vim.api.nvim_win_is_valid(win) then
            remove_hooks()
            return
        end
        local next_layout = M.layout(prompt, options, nil, nil, offset)
        offset = next_layout.offset
        if resize then
            local ok = pcall(vim.api.nvim_win_set_config, win, {
                relative = "editor",
                width = next_layout.width,
                height = next_layout.height,
                row = next_layout.row,
                col = next_layout.col,
            })
            if not ok then return end
        end
        layout = next_layout
        local choice = vim.api.nvim_win_get_cursor(win)[1] == YES_LINE
            and YES_LINE or NO_LINE
        write_lines(layout.lines)
        -- Keep the cursor on an action even when the file list changes size.
        if layout.height >= NO_LINE then
            vim.api.nvim_win_set_cursor(win, { choice, 0 })
        end
    end

    local function map(key, callback_fn)
        vim.keymap.set("n", key, callback_fn, {
            buffer = buf,
            noremap = true,
            silent = true,
            nowait = true,
        })
    end
    local function move(delta)
        if not vim.api.nvim_win_is_valid(win) then return end
        vim.api.nvim_win_set_cursor(win, {
            delta < 0 and YES_LINE or NO_LINE, 0,
        })
    end
    map("j", function() move(1) end)
    map("<Down>", function() move(1) end)
    map("k", function() move(-1) end)
    map("<Up>", function() move(-1) end)

    local function page(direction)
        if layout.page_size == 0 then return end
        local step = math.max(1, math.floor(layout.page_size / 2))
        offset = offset + direction * step
        redraw(false)
    end
    map("<C-d>", function() page(1) end)
    map("<PageDown>", function() page(1) end)
    map("<C-u>", function() page(-1) end)
    map("<PageUp>", function() page(-1) end)

    map("<CR>", function()
        if not vim.api.nvim_win_is_valid(win) then return end
        local yes = vim.api.nvim_win_get_cursor(win)[1] == YES_LINE
        close(false)
        callback(yes and "Yes" or "No")
    end)
    local function cancel() close(true) end
    map("q", cancel)
    map("<Esc>", cancel)
    map("<C-c>", cancel)

    resize_id = vim.api.nvim_create_autocmd("VimResized", {
        callback = function() redraw(true) end,
        desc = "Resize active Trash confirmation",
    })
    closed_id = vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        once = true,
        callback = function() remove_hooks() end,
        desc = "Clean up Trash confirmation resize handler",
    })
    return true
end

return M
