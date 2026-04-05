local M = {}

local nicetstamp = require("extensions.nicetstamp")  -- NEW

-- -- debugger
-- local function dbg(label, fn)
--   local ok, err = pcall(fn)
--   if not ok then
--     vim.notify(("[output][FAIL @ %s] %s"):format(label, tostring(err)), vim.log.levels.ERROR)
--     error(err)
--   else
--     vim.notify(("[output][OK   @ %s]"):format(label), vim.log.levels.DEBUG)
--   end
-- end

local defaults = {
    default_mode = "split", -- "split" | "float"
    name = "[output]",
    float = {
        width  = 0.8,          -- fraction (0..1) or absolute cols
        height = 0.6,          -- fraction (0..1) or absolute rows
        border = "rounded",    -- "single" | "double" | "rounded" | "solid" | "shadow" (plenary)
        title  = "Output",
        filetype = "runoutput",
        winblend = 0,          -- transparency
    },
}

local config = vim.tbl_deep_extend("force", {}, defaults)
local RunOut = { buf = nil, name = config.name }

local FloatOut = { win = nil, buf = nil }

-- ========== split mode ==========

local function ensure_output_window()
    if not (RunOut.buf and vim.api.nvim_buf_is_valid(RunOut.buf)) then
        vim.cmd("botright new")
        RunOut.buf = vim.api.nvim_get_current_buf()
        pcall(vim.api.nvim_buf_set_name, RunOut.buf, config.name)
        vim.bo[RunOut.buf].buftype = "nofile"
        vim.bo[RunOut.buf].bufhidden = "hide"
        vim.bo[RunOut.buf].swapfile = false
        vim.bo[RunOut.buf].modifiable = false
        vim.bo[RunOut.buf].filetype = config.float.filetype or "runoutput"
        -- vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = RunOut.buf, silent = true })
        vim.keymap.set("n", "q", function() M.toggle("split") end,
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

    local width  = dims_from_fraction(config.float.width,  "width")
    local height = dims_from_fraction(config.float.height, "height")

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
    local borderchars = borderchars_for(config.float.border)

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
    vim.bo[bufnr].filetype  = config.float.filetype or "runoutput"

    if old_ts then vim.b[bufnr].nicetstamp_ts = old_ts end
    if old_hdrn then vim.b[bufnr].nicetstamp_hdr_n = old_hdrn end

    -- restore previous contents when we had only closed the window
    if old_lines and #old_lines > 0 then
        vim.bo[bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, old_lines)
        vim.bo[bufnr].modifiable = false
    end

    -- window opts (avoid set_option_value; use vim.wo for compatibility)
    if type(config.float.winblend) == "number" and config.float.winblend > 0 then
        vim.wo[win_id].winblend = config.float.winblend
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

    vim.keymap.set("n", "q", function() M.toggle("float") end,
    { buffer = bufnr, nowait = true, silent = true })

    vim.keymap.set("n", "<Esc>", function() M.toggle("float") end,
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
        write_output_buffer(contents)
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

-- ========== runner ==========

local function capture_command(cmd, file)
    local ok, result = pcall(vim.fn.systemlist, { cmd, file })
    local out = {}
    if not ok then
        out = { "Failed to run: " .. tostring(cmd) .. " " .. tostring(file) }
        return out, 1
    end
    out = result or {}
    local code = vim.v.shell_error or 0
    return out, code
end

-- opts: { cmd, file, lines, mode="split"|"float", float={width,height,title,filetype,border} }
function M.run(opts)
    if not opts or not opts.cmd then
        vim.notify("output.run: missing opts.cmd", vim.log.levels.ERROR)
        return
    end

    local file = opts.file or vim.fn.expand("%:p")
    local lines_pad = opts.lines or 0
    local mode = opts.mode or config.default_mode

    local lead = {}
    for _ = 1, lines_pad do table.insert(lead, "") end

    local out, code = capture_command(opts.cmd, file)
    if code ~= 0 then table.insert(out, string.format("[exit %d]", code)) end
    for i = #lead, 1, -1 do table.insert(out, 1, lead[i]) end

    if mode == "float" then
        if opts.float then
            config.float = vim.tbl_deep_extend("force", config.float, opts.float)
        end
        write_output_float(out)
    else
        write_output_buffer(out)
    end
end

-- convenience
function M.run_file_in_split(cmd, file, lines)
    M.run({ cmd = cmd, file = file, lines = lines or 0, mode = "split" })
end

function M.run_file_in_float(cmd, file, lines, float_opts)
    M.run({ cmd = cmd, file = file, lines = lines or 0, mode = "float", float = float_opts })
end

function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})
    config.name = tostring(config.name or "[output]") -- ensure string

    assert(type(config.name) == "string", "config.name type=" .. type(config.name))
    assert(type(config.float.border) == "string", "border type=" .. type(config.float.border))

    RunOut.name = config.name
end

function M.status()
    local split_buf_valid = RunOut.buf and vim.api.nvim_buf_is_valid(RunOut.buf) or false
    local split_win = split_buf_valid and vim.fn.win_findbuf(RunOut.buf)[1] or nil

    local float_buf_valid = FloatOut.buf and vim.api.nvim_buf_is_valid(FloatOut.buf) or false
    local float_win_valid = FloatOut.win and vim.api.nvim_win_is_valid(FloatOut.win) or false

    return {
        split = { buf = RunOut.buf, buf_valid = split_buf_valid, win = split_win },
        float = { buf = FloatOut.buf, buf_valid = float_buf_valid, win = float_win_valid and FloatOut.win or nil },
        default_mode = config.default_mode,
    }
end

local function _is_visible_buf(buf)
    if not (buf and vim.api.nvim_buf_is_valid(buf)) then return false end
    return #vim.fn.win_findbuf(buf) > 0
end

function M.toggle(mode)
    mode = mode or config.default_mode
    if mode == "float" then
        -- if open, close; else open (create or reuse)
        if FloatOut.win and vim.api.nvim_win_is_valid(FloatOut.win) then
            vim.api.nvim_win_close(FloatOut.win, true)
            return
        end
        ensure_float_window()  -- centers + focuses
    else -- "split"
        local b = RunOut.buf
        if _is_visible_buf(b) then
            local win = vim.fn.win_findbuf(b)[1]
            if win then vim.api.nvim_win_close(win, true) end
            return
        end
        ensure_output_window()
    end
end

return M
