return function(context)
    local nicetstamp = context.nicetstamp
    local state = context.state
    local write_split = context.write_split
    local M = {}
    local FloatOut = {
        win = nil,
        buf = nil,
    }

    -- ========== float (plenary) mode ==========

    local function dims_from_fraction(val, axis)
        if type(val) == "number" and val > 0 and val < 1 then
            if axis == "width" then
                return math.max(10, math.floor(vim.o.columns * val))
            else
                return math.max(5, math.floor(vim.o.lines * val))
            end
        end
        return val
    end

    local function ensure_float_window()
        local ok, popup = pcall(require, "plenary.popup")
        if not ok then
            vim.notify("plenary.popup not available; falling back to split.", vim.log.levels.WARN)
            return nil, nil
        end

        local width  = dims_from_fraction(state.config.float.width,  "width")
        local height = dims_from_fraction(state.config.float.height, "height")

        -- Reuse if still valid
        if FloatOut.win and vim.api.nvim_win_is_valid(FloatOut.win)
            and FloatOut.buf and vim.api.nvim_buf_is_valid(FloatOut.buf) then
            local col = math.floor((vim.o.columns - width) / 2)
            local row = math.floor((vim.o.lines   - height) / 2)
            vim.api.nvim_win_set_config(FloatOut.win, {
                relative = "editor",
                width = width, height = height, col = col, row = row,
                style = "minimal",
            })

            nicetstamp.refresh_header(FloatOut.buf, nicetstamp.get(FloatOut.buf))
            nicetstamp.attach_autorefresh(FloatOut.buf, 5)

            return FloatOut.buf, FloatOut.win
        end

        -- local old_lines = nil
        -- if FloatOut.buf and vim.api.nvim_buf_is_valid(FloatOut.buf) then
        --     old_lines = vim.api.nvim_buf_get_lines(FloatOut.buf, 0, -1, false)
        -- end
        local old_lines, old_ts, old_hdrn = nil, nil, nil
        if FloatOut.buf and vim.api.nvim_buf_is_valid(FloatOut.buf) then
            old_lines = vim.api.nvim_buf_get_lines(FloatOut.buf, 0, -1, false)
            old_ts    = vim.b[FloatOut.buf].nicetstamp_ts
            old_hdrn  = vim.b[FloatOut.buf].nicetstamp_hdr_n
        end

        -- map border style -> plenary borderchars
        local function borderchars_for(style)
            if style == "double" then
                return { "═","║","═","║","╔","╗","╝","╚" }
            elseif style == "single" then
                return { "─","│","─","│","┌","┐","┘","└" }
            else -- rounded default
                return { "─","│","─","│","╭","╮","╯","╰" }
            end
        end
        local borderchars = borderchars_for(state.config.float.border)

        local win_id, bufnr = popup.create({ "" }, {
            -- title       = config.name or "Output",
            highlight   = "Normal",
            line        = math.floor((vim.o.lines   - height) / 2),
            col         = math.floor((vim.o.columns - width)  / 2),
            minheight   = height,
            minwidth    = width,
            border      = true,
            borderchars = borderchars,
            zindex      = 50,
            enter       = true,
        })

        -- If pcall failed earlier, we rethrew, so we only get here on success.
        -- Still, be defensive:
        if type(win_id) ~= "number" then
            error("popup.create returned non-numeric win_id: " .. tostring(win_id))
        end

        if type(bufnr) ~= "number" then
            if vim.api.nvim_win_is_valid(win_id) then
                bufnr = vim.api.nvim_win_get_buf(win_id)
            end
        end

        assert(type(bufnr) == "number", "popup.create produced invalid bufnr")

        FloatOut.win = win_id
        FloatOut.buf = bufnr

        vim.bo[bufnr].buftype   = "nofile"
        -- vim.bo[bufnr].bufhidden = "wipe"
        vim.bo[bufnr].bufhidden = "hide"
        vim.bo[bufnr].swapfile  = false
        vim.bo[bufnr].modifiable = false
        vim.bo[bufnr].filetype  = state.config.float.filetype or "runoutput"

        if old_ts then vim.b[bufnr].nicetstamp_ts = old_ts end
        if old_hdrn then vim.b[bufnr].nicetstamp_hdr_n = old_hdrn end

        -- restore previous contents when we had only closed the window
        if old_lines and #old_lines > 0 then
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, old_lines)
            vim.bo[bufnr].modifiable = false
        end

        -- window opts (avoid set_option_value; use vim.wo for compatibility)
        if type(state.config.float.winblend) == "number" and state.config.float.winblend > 0 then
            vim.wo[win_id].winblend = state.config.float.winblend
        end

        -- close keys
        -- vim.keymap.set("n", "q", function()
        --     if FloatOut.win and vim.api.nvim_win_is_valid(FloatOut.win) then
        --         vim.api.nvim_win_close(FloatOut.win, true)
        --     end
        -- end, { buffer = bufnr, nowait = true, silent = true })

        -- vim.keymap.set("n", "<Esc>", function()
        --     if FloatOut.win and vim.api.nvim_win_is_valid(FloatOut.win) then
        --         vim.api.nvim_win_close(FloatOut.win, true)
        --     end
        -- end, { buffer = bufnr, nowait = true, silent = true })

        vim.keymap.set("n", "q", function() M.toggle() end,
            { buffer = bufnr, nowait = true, silent = true })

        vim.keymap.set("n", "<Esc>", function() M.toggle() end,
            { buffer = bufnr, nowait = true, silent = true })

        nicetstamp.refresh_header(bufnr, nicetstamp.get(bufnr))
        nicetstamp.attach_autorefresh(bufnr, 5)

        return bufnr, win_id
    end

    -- local function write_output_float(contents)
    --     local buf, win = ensure_float_window()
    --     if not (buf and win) then
    --         -- fallback
    --         write_output_buffer(contents)
    --         return
    --     end

    --     vim.bo[buf].modifiable = true
    --     local lines = {}
    --     if type(contents) == "string" then
    --         for s in contents:gmatch("([^\n]*)\n?") do table.insert(lines, s) end
    --     elseif type(contents) == "table" then
    --         lines = contents
    --     else
    --         lines = { tostring(contents) }
    --     end
    --     vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    --     vim.bo[buf].modifiable = false

    --     pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
    -- end

    local function write_output_float(contents)
        local buf, win = ensure_float_window()
        if not (buf and win) then
            write_split(contents)
            return
        end

        -- normalize contents -> table
        local lines = {}
        if type(contents) == "string" then
            for s in contents:gmatch("([^\n]*)\n?") do table.insert(lines, s) end
        elseif type(contents) == "table" then
            lines = contents
        else
            lines = { tostring(contents) }
        end

        -- stamp + prepend header
        local ts = os.time()
        nicetstamp.set(buf, ts)
        local out = nicetstamp.prepend_header(lines, ts)  -- or {buf = buf} if you prefer

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
        vim.bo[buf].modifiable = false

        pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
    end


    M.write = write_output_float

    function M.status()
        local buf_valid =
        FloatOut.buf
        and vim.api.nvim_buf_is_valid(
            FloatOut.buf
        )
        or false
        local win_valid =
        FloatOut.win
        and vim.api.nvim_win_is_valid(
            FloatOut.win
        )
        or false

        return {
            buf = FloatOut.buf,
            buf_valid = buf_valid,
            win = win_valid
                and FloatOut.win
                or nil,
        }
    end

    function M.toggle()
        if
            FloatOut.win
            and vim.api.nvim_win_is_valid(
                FloatOut.win
            )
        then
            vim.api.nvim_win_close(
                FloatOut.win,
                true
            )
            return
        end

        ensure_float_window()
    end

    return M
end
