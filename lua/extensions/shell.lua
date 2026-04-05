-- local Popup = require("plenary.popup")
local Job   = require("plenary.job")

local M = {}

local prev = { win = nil, buf = nil, mode = nil, modifiable = nil, readonly = nil }

local function focus_prev_window()
    if prev.win and vim.api.nvim_win_is_valid(prev.win) then
        pcall(vim.api.nvim_set_current_win, prev.win)
    end
end

local function leave_insert_if_needed()
    if vim.fn.mode():match("^[iR]") then
        vim.cmd.stopinsert()
    end
end

local function restore_prev_mode()
    if prev.mode and prev.mode:match("^[iR]") then
        vim.cmd.startinsert()
    end
end

local function restore_prev_buf_flags()
    if prev.buf and vim.api.nvim_buf_is_valid(prev.buf) then
        if prev.modifiable ~= nil then vim.bo[prev.buf].modifiable = prev.modifiable end
        if prev.readonly   ~= nil then vim.bo[prev.buf].readonly   = prev.readonly   end
    end
end

-- state
local state = {
    win = nil,
    buf = nil,
    input_line = "",      -- current editable input
    history = {},
    hist_idx = 0,
    ns = vim.api.nvim_create_namespace("shellline"),
}

local function current_buf_dir()
    local name = vim.api.nvim_buf_get_name(0)
    if name == "" then return vim.loop.cwd() end
    local dir = vim.fn.fnamemodify(name, ":p:h")
    return dir ~= "" and dir or vim.loop.cwd()
end

local function is_open()
    return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function close()
    leave_insert_if_needed()

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        -- try a polite close first; if it fails, force
        if not pcall(vim.api.nvim_win_close, state.win, false) then
            pcall(vim.api.nvim_win_close, state.win, true)
        end
    end

    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
        pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
    end
    state.win, state.buf = nil, nil

    focus_prev_window()
    restore_prev_buf_flags()
    restore_prev_mode()

    prev.win, prev.buf, prev.mode, prev.modifiable, prev.readonly = nil, nil, nil, nil, nil
end

local function set_input(text)
    vim.schedule(function()
        if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then return end
        local last = vim.api.nvim_buf_line_count(state.buf)
        if last == 0 then
            vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "" })
            last = 1
        end
        -- overwrite the last (input) line with text (no "sh> " here; prompt adds it visually)
        vim.api.nvim_buf_set_lines(state.buf, last-1, last, false, { text or "" })
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_set_cursor(state.win, { last, (text and #text or 0) })
        end
    end)
end

local function append(lines)
    if type(lines) == "string" then
        lines = vim.split(lines, "\n", { plain = true })
    end
    vim.schedule(function()
        if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then return end
        local last = vim.api.nvim_buf_line_count(state.buf)
        -- insert before prompt if it exists, else at top (0) for brand-new buffer
        local insert_at = (last > 0) and (last - 1) or 0
        vim.api.nvim_buf_set_lines(state.buf, insert_at, insert_at, false, lines)
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_set_cursor(state.win, { vim.api.nvim_buf_line_count(state.buf), 0 })
        end
    end)
end

local function normalize_prompt_tail()
    vim.schedule(function()
        if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then return end
        local last = vim.api.nvim_buf_line_count(state.buf)
        if last == 0 then
            vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "" })
            return
        end
        while last > 0 do
            local ln = vim.api.nvim_buf_get_lines(state.buf, last-1, last, false)[1]
            if ln ~= "" then break end
            last = last - 1
        end
        local head = vim.api.nvim_buf_get_lines(state.buf, 0, last, false)
        vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, head)
        vim.api.nvim_buf_set_lines(state.buf, -1, -1, false, { "" })
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            vim.api.nvim_win_set_cursor(state.win, { vim.api.nvim_buf_line_count(state.buf), 0 })
        end
    end)
end

local function arm_prompt()
    normalize_prompt_tail()
end

local function history_push(cmd)
    if cmd == "" then return end
    if #state.history == 0 or state.history[#state.history] ~= cmd then
        table.insert(state.history, cmd)
    end
    state.hist_idx = #state.history + 1
end

local function history_prev()
    if #state.history == 0 then return end
    state.hist_idx = math.max(1, state.hist_idx - 1)
    set_input(state.history[state.hist_idx] or "")
end

local function history_next()
    if #state.history == 0 then return end
    state.hist_idx = math.min(#state.history + 1, state.hist_idx + 1)
    set_input(state.history[state.hist_idx] or "")
end

local function parse_cmdline(cmdline)
    -- Split like a shell-ish whitespace splitter (simple; no quotes escaping)
    local parts = vim.fn.split(cmdline, [[\s\+]])
    local cmd = parts[1]
    local args = {}
    for i = 2, #parts do args[#args+1] = parts[i] end
    return cmd, args
end

local function run_job(cmdline, stdin_lines)
    if cmdline == "" then return end
    history_push(cmdline)
    append({ "", "$ " .. cmdline })

    local cmd, args = parse_cmdline(cmdline)
    if not cmd or cmd == "" then
        append({ "[shellline] no command" })
        vim.schedule(function() vim.cmd.startinsert({ bang = true }) end)
        return
    end

    local j = Job:new({
        command = cmd,
        args = args,
        cwd = current_buf_dir(),
        on_stdout = vim.schedule_wrap(function(_, data)
            if data and data ~= "" then append(data) end
        end),
        on_stderr = vim.schedule_wrap(function(_, data)
            if data and data ~= "" then append(data) end
        end),
        on_exit = vim.schedule_wrap(function(_, code)
            append(string.format("[exit %d]", code))
            arm_prompt()
            vim.cmd.startinsert({ bang = true })
        end),
    })

    j:start()
    if stdin_lines and #stdin_lines > 0 then
        for _, ln in ipairs(stdin_lines) do j:send(ln .. "\n") end
        j:shutdown()
    end
end

local function map_popup()
    local opts = { buffer = state.buf, nowait = true, silent = true, noremap = true }

    vim.keymap.set("n", "q", function()
        leave_insert_if_needed()
        close()
    end, opts)

    vim.keymap.set("i", "<C-q>", function()
        leave_insert_if_needed()
        close()
    end, opts)

    vim.keymap.set("i", "<C-u>", function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-u>", true, false, true), "int", false)
    end, opts)

    vim.keymap.set({ "n", "i" }, "<C-p>", history_prev, opts)
    vim.keymap.set({ "n", "i" }, "<C-n>", history_next, opts)

    vim.keymap.set({ "n", "i" }, "!!", function()
        if #state.history > 0 then run_job(state.history[#state.history], nil) end
    end, opts)
end

function M.toggle()
    if is_open() then
        close()
        return
    end

    prev.win        = vim.api.nvim_get_current_win()
    prev.buf        = vim.api.nvim_get_current_buf()
    prev.mode       = vim.fn.mode()
    prev.modifiable = vim.bo[prev.buf].modifiable
    prev.readonly   = vim.bo[prev.buf].readonly

    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].buftype = "prompt"
    vim.bo[state.buf].bufhidden = "wipe"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "shellline"

    local width  = math.floor(vim.o.columns * 0.8)
    local height = 12
    local col    = math.floor((vim.o.columns - width) / 2)
    local row    = math.floor(vim.o.lines - height - 4)

    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = "rounded",
    })

    vim.wo[state.win].number = false
    vim.wo[state.win].relativenumber = false
    vim.wo[state.win].cursorline = false
    vim.wo[state.win].wrap = false

    vim.fn.prompt_setprompt(state.buf, "sh> ")
    vim.fn.prompt_setcallback(
      state.buf,
      vim.schedule_wrap(function(line)
        if not line or line == "" then
          vim.cmd.startinsert({ bang = true })
          return
        end
        run_job(line, nil)
      end)
    )

    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "" })

    append({
        "shellline — cwd: " .. current_buf_dir(),
        "Type a command and press <Enter>. q to close.",
        ""
    })

    map_popup()
    vim.api.nvim_win_set_cursor(state.win, { vim.api.nvim_buf_line_count(state.buf), 0 })
    vim.cmd.startinsert({ bang = true })
end

function M.run_here_with_visual_stdin(cmdline)
    if not cmdline or cmdline == "" then
        vim.notify("Provide a command, e.g. :'<,'>ShellHere sort", vim.log.levels.WARN)
        return
    end
    local _, ls = unpack(vim.fn.getpos("'<"))
    local _, le = unpack(vim.fn.getpos("'>"))
    local lines = vim.api.nvim_buf_get_lines(0, ls-1, le, false)
    if #lines == 0 then lines = { "" } end

    if not is_open() then M.toggle() end
    run_job(cmdline, lines)
end

return M
