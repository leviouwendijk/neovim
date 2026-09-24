return function(context)
    local nicetstamp = context.nicetstamp
    local state = context.state
    local M = {}
    local RunOut = {
        buf = nil,
        name = state.config.name,
    }

    -- ========== split mode ==========

    local function ensure_output_window()
        if not (RunOut.buf and vim.api.nvim_buf_is_valid(RunOut.buf)) then
            vim.cmd("botright new")
            RunOut.buf = vim.api.nvim_get_current_buf()
            pcall(vim.api.nvim_buf_set_name, RunOut.buf, state.config.name)
            vim.bo[RunOut.buf].buftype = "nofile"
            vim.bo[RunOut.buf].bufhidden = "hide"
            vim.bo[RunOut.buf].swapfile = false
            vim.bo[RunOut.buf].modifiable = false
            vim.bo[RunOut.buf].filetype = state.config.float.filetype or "runoutput"
            -- vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = RunOut.buf, silent = true })
            vim.keymap.set("n", "q", function() M.toggle() end,
                { buffer = RunOut.buf, silent = true, nowait = true })
        else
            local wins = vim.fn.win_findbuf(RunOut.buf)
            if #wins == 0 then
                vim.cmd("botright new")
                vim.api.nvim_win_set_buf(0, RunOut.buf)
            else
                vim.api.nvim_set_current_win(wins[1])
            end
        end

        nicetstamp.refresh_header(RunOut.buf, nicetstamp.get(RunOut.buf))
        nicetstamp.attach_autorefresh(RunOut.buf, 5)

        return RunOut.buf
    end

    -- local function write_output_buffer(contents)
    --     local buf = ensure_output_window()
    --     assert(type(buf) == "number", "output: buffer id missing")

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

    --     local wins = vim.fn.win_findbuf(buf)
    --     if #wins > 0 then
    --         local win = wins[1]
    --         vim.api.nvim_win_set_cursor(win, { 1, 0 })
    --         vim.api.nvim_set_current_win(win)
    --     else
    --         vim.cmd("botright split")
    --         vim.api.nvim_win_set_buf(0, buf)
    --         vim.api.nvim_win_set_cursor(0, { 1, 0 })
    --     end
    -- end

    local function write_output_buffer(contents)
        local buf = ensure_output_window()
        assert(type(buf) == "number", "output: buffer id missing")

        -- normalize contents -> table
        local lines = {}
        if type(contents) == "string" then
            for s in contents:gmatch("([^\n]*)\n?") do table.insert(lines, s) end
        elseif type(contents) == "table" then
            lines = contents
        else
            lines = { tostring(contents) }
        end

        -- stamp, build header+body, write
        local ts = os.time()
        nicetstamp.set(buf, ts) -- stores ts on buffer + writes/refreshes line 1
        local out = nicetstamp.prepend_header(lines, ts)

        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
        vim.bo[buf].modifiable = false

        local wins = vim.fn.win_findbuf(buf)
        if #wins > 0 then
            local win = wins[1]
            pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })
            vim.api.nvim_set_current_win(win)
        else
            vim.cmd("botright split")
            vim.api.nvim_win_set_buf(0, buf)
            pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
        end
    end


    M.write = write_output_buffer

    function M.set_name(name)
        RunOut.name = name
    end

    function M.status()
        local buf_valid =
        RunOut.buf
        and vim.api.nvim_buf_is_valid(
            RunOut.buf
        )
        or false
        local win =
        buf_valid
        and vim.fn.win_findbuf(
            RunOut.buf
        )[1]
        or nil

        return {
            buf = RunOut.buf,
            buf_valid = buf_valid,
            win = win,
        }
    end

    local function _is_visible_buf(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end
        return #vim.fn.win_findbuf(buf) > 0
    end

    function M.toggle()
        local b = RunOut.buf
        if _is_visible_buf(b) then
            local win = vim.fn.win_findbuf(b)[1]
            if win then vim.api.nvim_win_close(win, true) end
            return
        end
        ensure_output_window()
    end

    return M
end
